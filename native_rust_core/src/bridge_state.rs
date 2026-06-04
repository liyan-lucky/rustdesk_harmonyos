use std::sync::{Mutex, OnceLock};

#[derive(Clone, Debug)]
pub struct BridgeSnapshot {
    pub adapter: String,
    pub core_ready: bool,
    pub incoming_ready: bool,
    pub display_id: String,
    pub fingerprint: String,
    pub direct_address: String,
    pub status_summary: String,
    pub detail_message: String,
    pub server: String,
    pub session_stage: String,
    pub active_peer_id: String,
    pub last_error: String,
}

impl BridgeSnapshot {
    pub fn new_stub(server: &str) -> Self {
        Self {
            adapter: "native-stub".to_owned(),
            core_ready: false,
            incoming_ready: false,
            display_id: String::new(),
            fingerprint: "Pending official native core".to_owned(),
            direct_address: "Pending official native core".to_owned(),
            status_summary: "Rust bridge ABI ready, official core logic still missing".to_owned(),
            detail_message: "The Rust bridge crate exports the expected ABI now. Next step is wiring official RustDesk core registration and session logic here.".to_owned(),
            server: server.to_owned(),
            session_stage: "idle".to_owned(),
            active_peer_id: String::new(),
            last_error: String::new(),
        }
    }

    pub fn to_json(&self) -> String {
        format!(
            concat!(
                "{{",
                "\"adapter\":\"{}\",",
                "\"coreReady\":{},",
                "\"incomingReady\":{},",
                "\"displayId\":\"{}\",",
                "\"fingerprint\":\"{}\",",
                "\"directAddress\":\"{}\",",
                "\"statusSummary\":\"{}\",",
                "\"detailMessage\":\"{}\",",
                "\"server\":\"{}\",",
                "\"sessionStage\":\"{}\",",
                "\"activePeerId\":\"{}\",",
                "\"lastError\":\"{}\"",
                "}}"
            ),
            escape_json(&self.adapter),
            if self.core_ready { "true" } else { "false" },
            if self.incoming_ready { "true" } else { "false" },
            escape_json(&self.display_id),
            escape_json(&self.fingerprint),
            escape_json(&self.direct_address),
            escape_json(&self.status_summary),
            escape_json(&self.detail_message),
            escape_json(&self.server),
            escape_json(&self.session_stage),
            escape_json(&self.active_peer_id),
            escape_json(&self.last_error),
        )
    }
}

fn escape_json(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\r', "\\r")
}

static SNAPSHOT: OnceLock<Mutex<BridgeSnapshot>> = OnceLock::new();
static SESSION_EVENTS: OnceLock<Mutex<Vec<String>>> = OnceLock::new();

pub fn snapshot_store() -> &'static Mutex<BridgeSnapshot> {
    SNAPSHOT.get_or_init(|| Mutex::new(BridgeSnapshot::new_stub("")))
}

pub fn session_event_store() -> &'static Mutex<Vec<String>> {
    SESSION_EVENTS.get_or_init(|| Mutex::new(Vec::new()))
}

pub fn queue_session_event(kind: &str, detail: &str, peer_id: &str) {
    let event = format!(
        concat!(
            "{{",
            "\"kind\":\"{}\",",
            "\"detail\":\"{}\",",
            "\"peerId\":\"{}\",",
            "\"timestamp\":{}",
            "}}"
        ),
        escape_json(kind),
        escape_json(detail),
        escape_json(peer_id),
        current_timestamp_millis(),
    );
    let mut guard = session_event_store()
        .lock()
        .expect("session event mutex should not be poisoned");
    guard.push(event);
    if guard.len() > 50 {
        let drain_count = guard.len() - 50;
        guard.drain(0..drain_count);
    }
}

pub fn drain_session_events_json() -> String {
    let mut guard = session_event_store()
        .lock()
        .expect("session event mutex should not be poisoned");
    let drained = guard.drain(..).collect::<Vec<String>>();
    format!("[{}]", drained.join(","))
}

fn current_timestamp_millis() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};

    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_millis() as i64,
        Err(_) => 0,
    }
}
