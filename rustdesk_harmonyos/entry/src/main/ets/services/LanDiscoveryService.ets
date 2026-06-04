import { OfficialRustDeskBridge } from './OfficialRustDeskBridge';
import { NativeRustDeskBridge } from './NativeRustDeskBridge';
import { AppDataService, AddressBookEntry } from './AppDataService';
import { PreferenceStore } from './PreferenceStore';
import { DeviceIdFormatter } from '../common/DeviceIdFormatter';

export interface DiscoveredPeer {
  id: string;
  username: string;
  hostname: string;
  platform: string;
  online: boolean;
}

export type LanDiscoveryListener = () => void;

export class LanDiscoveryService {
  private static instance: LanDiscoveryService;
  private discoveryTimer: number = -1;
  private discoveredPeers: Map<string, DiscoveredPeer> = new Map();
  private ignoredPeerIds: Set<string> = new Set();
  private discoveryInterval: number = 30000;
  private isDiscovering: boolean = false;
  private ignoredPeerIdsLoaded: boolean = false;
  private listeners: LanDiscoveryListener[] = [];

  private constructor() {}

  static getInstance(): LanDiscoveryService {
    if (!LanDiscoveryService.instance) {
      LanDiscoveryService.instance = new LanDiscoveryService();
    }
    return LanDiscoveryService.instance;
  }

  startDiscovery(): void {
    if (this.isDiscovering) {
      return;
    }
    this.loadIgnoredPeerIds();
    this.isDiscovering = true;
    NativeRustDeskBridge.setLocalOption('enable-lan-discovery', 'Y');
    console.log('[LanDiscovery] Starting periodic LAN discovery (interval=' + this.discoveryInterval + 'ms)');
    this.discoverOnce();
    this.discoveryTimer = setInterval(() => {
      this.discoverOnce();
    }, this.discoveryInterval);
  }

  stopDiscovery(): void {
    if (this.discoveryTimer !== -1) {
      clearInterval(this.discoveryTimer);
      this.discoveryTimer = -1;
    }
    this.isDiscovering = false;
    NativeRustDeskBridge.setLocalOption('enable-lan-discovery', 'N');
  }

  refreshNow(): void {
    this.ignoredPeerIds.clear();
    this.persistIgnoredPeerIds();
    this.ignoredPeerIdsLoaded = true;
    NativeRustDeskBridge.setLocalOption('enable-lan-discovery', 'Y');
    if (!this.isDiscovering) {
      this.isDiscovering = true;
      this.discoverOnce();
      this.discoveryTimer = setInterval(() => {
        this.discoverOnce();
      }, this.discoveryInterval);
      return;
    }
    const result = OfficialRustDeskBridge.getInstance().discoverLanPeers();
    console.log('[LanDiscovery] refreshNow discoverLanPeers returned:', result);
    setTimeout(() => {
      this.loadDiscoveredPeers();
    }, 1500);
    setTimeout(() => {
      this.loadDiscoveredPeers();
    }, 3500);
  }

  private resetCurrentDiscoveryResults(): void {
    this.discoveredPeers.clear();
    AppDataService.getInstance().clearDiscoveredDevices();
    this.notifyListeners();
  }

  private discoverOnce(): void {
    const result = OfficialRustDeskBridge.getInstance().discoverLanPeers();
    console.log('[LanDiscovery] discoverLanPeers returned:', result);
    setTimeout(() => {
      this.loadDiscoveredPeers();
    }, 1500);
    setTimeout(() => {
      this.loadDiscoveredPeers();
    }, 3500);
  }

  private loadDiscoveredPeers(): void {
    const jsonStr = OfficialRustDeskBridge.getInstance().loadLanPeers();
    console.log('[LanDiscovery] loadLanPeers returned:', jsonStr.substring(0, Math.min(200, jsonStr.length)));
    if (!this.ignoredPeerIdsLoaded) {
      this.loadIgnoredPeerIds();
    }
    const nativePeerIds: Set<string> = new Set();
    if (jsonStr && jsonStr !== '[]') {
      try {
        const peers = JSON.parse(jsonStr) as Array<Record<string, string | boolean>>;
        console.log('[LanDiscovery] Parsed peers count:', peers.length);
        if (Array.isArray(peers)) {
          peers.forEach((peer: Record<string, string | boolean>) => {
            const id = (peer['id'] as string) || '';
            if (id.length === 0) {
              return;
            }
            const normalizedId = DeviceIdFormatter.parse(id);
            if (normalizedId.length === 0 || this.ignoredPeerIds.has(normalizedId)) {
              return;
            }
            nativePeerIds.add(normalizedId);
            const discoveredPeer: DiscoveredPeer = {
              id: id,
              username: (peer['username'] as string) || '',
              hostname: (peer['hostname'] as string) || '',
              platform: (peer['platform'] as string) || '',
              online: peer['online'] === true
            };
            this.handleDiscoveredPeer(discoveredPeer);
          });
        }
      } catch (e) {
        console.error('[LanDiscovery] loadDiscoveredPeers parse error', e);
      }
    }
    let removed = false;
    this.discoveredPeers.forEach((_peer: DiscoveredPeer, id: string) => {
      if (!nativePeerIds.has(id)) {
        this.discoveredPeers.delete(id);
        AppDataService.getInstance().removeDiscoveredDevice(id);
        removed = true;
      }
    });
    if (removed) {
      this.notifyListeners();
    }
  }

  handleDiscoveredPeer(peer: DiscoveredPeer): void {
    const normalizedId = DeviceIdFormatter.parse(peer.id);
    if (normalizedId.length === 0) {
      return;
    }
    if (this.ignoredPeerIds.has(normalizedId)) {
      return;
    }
    let resolvedUsername = peer.username;
    let resolvedHostname = peer.hostname;
    let resolvedPlatform = peer.platform;
    if (resolvedUsername.length === 0 || resolvedHostname.length === 0 || resolvedPlatform.length === 0) {
      const info = NativeRustDeskBridge.getPeerInfo(peer.id);
      if (resolvedHostname.length === 0 && info.hostname.length > 0) {
        resolvedHostname = info.hostname;
      }
      if (resolvedUsername.length === 0 && info.username.length > 0) {
        resolvedUsername = info.username;
      }
      if (resolvedPlatform.length === 0 && info.platform.length > 0) {
        resolvedPlatform = info.platform;
      }
    }
    const enrichedPeer: DiscoveredPeer = {
      id: normalizedId,
      username: resolvedUsername,
      hostname: resolvedHostname,
      platform: resolvedPlatform,
      online: peer.online
    };
    const previous = this.discoveredPeers.get(normalizedId);
    this.discoveredPeers.set(normalizedId, enrichedPeer);
    const appData = AppDataService.getInstance();
    const alias = resolvedUsername.length > 0 && resolvedHostname.length > 0
      ? (resolvedHostname.startsWith(`${resolvedUsername}@`) ? resolvedHostname : `${resolvedUsername}@${resolvedHostname}`)
      : (resolvedHostname.length > 0 ? resolvedHostname : resolvedUsername);
    const entry: AddressBookEntry = {
      id: normalizedId,
      alias: alias,
      note: '',
      group: '',
      online: peer.online,
      favorite: false,
      platform: resolvedPlatform
    };
    appData.addDiscoveredDevice(entry);
    if (peer.online) {
      appData.markLanPeerOnline(normalizedId, this.discoveryInterval * 3);
    }
    if (!previous ||
      previous.username !== enrichedPeer.username ||
      previous.hostname !== enrichedPeer.hostname ||
      previous.platform !== enrichedPeer.platform ||
      previous.online !== enrichedPeer.online) {
      this.notifyListeners();
    }
  }

  removeDiscoveredPeer(id: string): void {
    const normalizedId = DeviceIdFormatter.parse(id);
    if (normalizedId.length === 0) {
      return;
    }
    this.ignoredPeerIdsLoaded = false;
    this.loadIgnoredPeerIds();
    this.ignoredPeerIds.add(normalizedId);
    this.persistIgnoredPeerIds();
    this.discoveredPeers.delete(normalizedId);
    const appData = AppDataService.getInstance();
    appData.removeDiscoveredDevice(normalizedId);
    appData.updateOnlineStatusFromResult([], [normalizedId]);
    this.notifyListeners();
  }

  getDiscoveredPeers(): DiscoveredPeer[] {
    return Array.from(this.discoveredPeers.values());
  }

  clearDiscoveredPeers(): void {
    this.discoveredPeers.clear();
    this.ignoredPeerIds.clear();
    this.ignoredPeerIdsLoaded = false;
    this.persistIgnoredPeerIds();
    AppDataService.getInstance().clearDiscoveredDevices();
    this.notifyListeners();
  }

  addListener(listener: LanDiscoveryListener): void {
    if (this.listeners.indexOf(listener) >= 0) {
      return;
    }
    this.listeners.push(listener);
  }

  removeListener(listener: LanDiscoveryListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach((listener: LanDiscoveryListener) => {
      try {
        listener();
      } catch (error) {
        console.error('[LanDiscovery] listener failed', error);
      }
    });
  }

  private loadIgnoredPeerIds(): void {
    if (this.ignoredPeerIdsLoaded) {
      return;
    }
    this.ignoredPeerIdsLoaded = true;
    const raw = PreferenceStore.getIgnoredDiscoveredPeers();
    if (!raw) {
      return;
    }
    try {
      const ids = JSON.parse(raw) as string[];
      if (!Array.isArray(ids)) {
        return;
      }
      ids.forEach((id: string) => {
        const normalizedId = DeviceIdFormatter.parse(id);
        if (normalizedId.length > 0) {
          this.ignoredPeerIds.add(normalizedId);
        }
      });
    } catch (_error) {}
  }

  private persistIgnoredPeerIds(): void {
    PreferenceStore.setIgnoredDiscoveredPeers(JSON.stringify(Array.from(this.ignoredPeerIds)));
  }
}
