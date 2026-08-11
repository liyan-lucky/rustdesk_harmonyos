import image from '@ohos.multimedia.image';

@Component
export struct RemoteCursor {
  @Prop cursorX: number = 0;
  @Prop cursorY: number = 0;
  @Prop cursorVisible: boolean = false;
  @Prop cursorId: string = '';
  @Prop cursorImage: image.PixelMap | null = null;
  @Prop cursorHotX: number = 0;
  @Prop cursorHotY: number = 0;
  @Prop cursorImageWidth: number = 0;
  @Prop cursorImageHeight: number = 0;
  @Prop previewWidth: number = 0;
  @Prop previewHeight: number = 0;
  @Prop remoteWidth: number = 0;
  @Prop remoteHeight: number = 0;
  @Prop displayOriginX: number = 0;
  @Prop displayOriginY: number = 0;
  @Prop cursorScale: number = 1.0;

  private readonly cursorSize: number = 24;
  private readonly minCursorSize: number = 12;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.shouldShowCursor()) {
        Column() {
          this.buildCursorShape();
        }
        .width(this.resolveCursorRenderWidth())
        .height(this.resolveCursorRenderHeight())
        .margin({
          left: this.calculateDisplayX(),
          top: this.calculateDisplayY()
        });
      }
    }
    .width(this.previewWidth)
    .height(this.previewHeight)
    .hitTestBehavior(HitTestMode.None);
  }

  @Builder
  private buildCursorShape() {
    Column() {
      if (this.cursorImage !== null) {
        Image(this.cursorImage as image.PixelMap)
          .width(this.resolveCursorRenderWidth())
          .height(this.resolveCursorRenderHeight());
      } else {
        Image($rawfile('cursor-pointer.svg'))
          .width(this.resolveCursorRenderWidth())
          .height(this.resolveCursorRenderHeight())
          .objectFit(ImageFit.Fill);
      }
    }
    .hitTestBehavior(HitTestMode.None);
  }

  private shouldShowCursor(): boolean {
    return this.cursorVisible &&
      this.previewWidth > 0 &&
      this.previewHeight > 0 &&
      this.remoteWidth > 0 &&
      this.remoteHeight > 0;
  }

  private calculateDisplayX(): number {
    const scale = this.resolveDisplayScale();
    const localX = this.cursorX - this.displayOriginX;
    const maxX = Math.max(0, this.previewWidth - this.resolveCursorRenderWidth());
    return Math.max(0, Math.min(maxX, localX * scale - this.resolveCursorHotX()));
  }

  private calculateDisplayY(): number {
    const scale = this.resolveDisplayScale();
    const localY = this.cursorY - this.displayOriginY;
    const maxY = Math.max(0, this.previewHeight - this.resolveCursorRenderHeight());
    return Math.max(0, Math.min(maxY, localY * scale - this.resolveCursorHotY()));
  }

  private resolveDisplayScale(): number {
    const scaleX = this.previewWidth / this.remoteWidth;
    const scaleY = this.previewHeight / this.remoteHeight;
    const scale = Math.min(scaleX, scaleY);
    return Number.isFinite(scale) && scale > 0 ? scale : 1;
  }

  private resolveCursorScale(): number {
    if (this.cursorImage !== null && this.cursorImageWidth > 0 && this.cursorImageHeight > 0) {
      const baseScale = this.resolveDisplayScale();
      const minScale = this.minCursorSize / Math.max(this.cursorImageWidth, this.cursorImageHeight);
      return Math.max(baseScale, minScale) * this.cursorScale;
    }
    return this.cursorScale;
  }

  private resolveCursorRenderWidth(): number {
    if (this.cursorImage !== null && this.cursorImageWidth > 0) {
      return Math.max(1, Math.round(this.cursorImageWidth * this.resolveCursorScale()));
    }
    return Math.max(1, this.cursorSize * this.cursorScale);
  }

  private resolveCursorRenderHeight(): number {
    if (this.cursorImage !== null && this.cursorImageHeight > 0) {
      return Math.max(1, Math.round(this.cursorImageHeight * this.resolveCursorScale()));
    }
    return Math.max(1, this.cursorSize * this.cursorScale);
  }

  private resolveCursorHotX(): number {
    if (this.cursorImage !== null) {
      return this.cursorHotX * this.resolveCursorScale();
    }
    return this.resolveCursorRenderWidth() * 0.195;
  }

  private resolveCursorHotY(): number {
    if (this.cursorImage !== null) {
      return this.cursorHotY * this.resolveCursorScale();
    }
    return this.resolveCursorRenderHeight() * 0.261;
  }

  private getCursorPath(): string {
    const s = this.cursorSize;
    return `M 0 0 L ${s * 0.7} ${s * 0.5} L ${s * 0.45} ${s * 0.55} L ${s * 0.35} ${s * 0.9} L 0 0 Z`;
  }
}
