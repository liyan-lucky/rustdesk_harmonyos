const DEFAULT_FOREGROUND: string = '#D1FAE5';
const DEFAULT_BACKGROUND: string = '#020617';
const ANSI_COLORS: string[] = [
  '#000000', '#CD3131', '#0DBC79', '#E5E510', '#2472C8', '#BC3FBC', '#11A8CD', '#E5E5E5',
  '#666666', '#F14C4C', '#23D18B', '#F5F543', '#3B8EEA', '#D670D6', '#29B8DB', '#FFFFFF'
];

class TerminalStyle {
  foreground: string = DEFAULT_FOREGROUND;
  background: string = DEFAULT_BACKGROUND;
  bold: boolean = false;
  dim: boolean = false;
  italic: boolean = false;
  underline: boolean = false;
  inverse: boolean = false;
  hidden: boolean = false;
  strikeThrough: boolean = false;

  copy(): TerminalStyle {
    const result: TerminalStyle = new TerminalStyle();
    result.foreground = this.foreground;
    result.background = this.background;
    result.bold = this.bold;
    result.dim = this.dim;
    result.italic = this.italic;
    result.underline = this.underline;
    result.inverse = this.inverse;
    result.hidden = this.hidden;
    result.strikeThrough = this.strikeThrough;
    return result;
  }
}

class TerminalCell {
  text: string;
  style: TerminalStyle;
  width: number;

  constructor(text: string = ' ', style: TerminalStyle = new TerminalStyle(), width: number = 1) {
    this.text = text;
    this.style = style.copy();
    this.width = width;
  }

  copy(): TerminalCell {
    return new TerminalCell(this.text, this.style, this.width);
  }
}

export class TerminalRenderRun {
  text: string;
  foreground: string;
  background: string;
  bold: boolean;
  dim: boolean;
  italic: boolean;
  underline: boolean;
  strikeThrough: boolean;
  cursor: boolean;

  constructor(text: string, foreground: string, background: string, bold: boolean, dim: boolean,
    italic: boolean, underline: boolean, strikeThrough: boolean, cursor: boolean = false) {
    this.text = text;
    this.foreground = foreground;
    this.background = background;
    this.bold = bold;
    this.dim = dim;
    this.italic = italic;
    this.underline = underline;
    this.strikeThrough = strikeThrough;
    this.cursor = cursor;
  }
}

export class TerminalRenderLine {
  runs: TerminalRenderRun[];

  constructor(runs: TerminalRenderRun[]) {
    this.runs = runs;
  }
}

export class TerminalEmulator {
  private columns: number = 80;
  private rows: number = 24;
  private cursorRow: number = 0;
  private cursorColumn: number = 0;
  private savedRow: number = 0;
  private savedColumn: number = 0;
  private savedStyle: TerminalStyle = new TerminalStyle();
  private screen: TerminalCell[][] = [];
  private primaryScreen: TerminalCell[][] = [];
  private primaryCursorRow: number = 0;
  private primaryCursorColumn: number = 0;
  private history: TerminalCell[][] = [];
  private readonly historyLimit: number = 2000;
  private parserState: number = 0;
  private csi: string = '';
  private stringBuffer: string = '';
  private stringKind: number = 0;
  private currentStyle: TerminalStyle = new TerminalStyle();
  private scrollTop: number = 0;
  private scrollBottom: number = 23;
  private tabStops: boolean[] = [];
  private wrapPending: boolean = false;
  private autoWrap: boolean = true;
  private insertMode: boolean = false;
  private originMode: boolean = false;
  private alternateScreen: boolean = false;
  private cursorVisible: boolean = true;
  private applicationCursorKeys: boolean = false;
  private bracketedPaste: boolean = false;
  private title: string = '';
  private responses: string = '';
  private g0LineDrawing: boolean = false;
  private g1LineDrawing: boolean = false;
  private activeCharset: number = 0;
  private charsetTarget: number = 0;

  constructor(columns: number = 80, rows: number = 24) {
    this.columns = Math.max(1, columns);
    this.rows = Math.max(1, rows);
    this.scrollBottom = this.rows - 1;
    this.resetTabStops();
    this.reset();
  }

  resize(columns: number, rows: number): void {
    const newColumns: number = Math.max(1, columns);
    const newRows: number = Math.max(1, rows);
    this.columns = newColumns;
    this.rows = newRows;
    this.screen = this.resizeBuffer(this.screen, newRows, !this.alternateScreen);
    if (this.alternateScreen) {
      this.primaryScreen = this.resizeBuffer(this.primaryScreen, newRows, true);
    }
    this.cursorRow = Math.min(this.cursorRow, this.rows - 1);
    this.cursorColumn = Math.min(this.cursorColumn, this.columns - 1);
    this.scrollTop = 0;
    this.scrollBottom = this.rows - 1;
    this.wrapPending = false;
    this.resetTabStops();
    this.trimHistory();
  }

  consume(input: string): void {
    for (let index: number = 0; index < input.length; index++) {
      let character: string = input.charAt(index);
      const firstCode: number = input.charCodeAt(index);
      if (firstCode >= 0xD800 && firstCode <= 0xDBFF && index + 1 < input.length) {
        const secondCode: number = input.charCodeAt(index + 1);
        if (secondCode >= 0xDC00 && secondCode <= 0xDFFF) {
          character += input.charAt(index + 1);
          index++;
        }
      }

      if (this.parserState === 2) {
        if (character >= '@' && character <= '~') {
          this.applyCsi(character);
          this.parserState = 0;
          this.csi = '';
        } else if (this.csi.length < 256) {
          this.csi += character;
        } else {
          this.parserState = 0;
          this.csi = '';
        }
        continue;
      }
      if (this.parserState === 3) {
        if (character === '\u0007' || character === '\u009c') {
          this.finishControlString();
        } else if (character === '\u001b') {
          this.parserState = 4;
        } else if (this.stringKind === 1 && this.stringBuffer.length < 4096) {
          this.stringBuffer += character;
        }
        continue;
      }
      if (this.parserState === 4) {
        if (character === '\\') {
          this.finishControlString();
        } else {
          if (this.stringKind === 1 && this.stringBuffer.length < 4096) {
            this.stringBuffer += '\u001b' + character;
          }
          this.parserState = 3;
        }
        continue;
      }
      if (this.parserState === 1) {
        this.applyEscape(character);
        continue;
      }
      if (this.parserState === 5) {
        if (this.charsetTarget === 0) this.g0LineDrawing = character === '0';
        else if (this.charsetTarget === 1) this.g1LineDrawing = character === '0';
        this.parserState = 0;
        continue;
      }

      if (character === '\u009b') {
        this.parserState = 2;
        this.csi = '';
      } else if (character === '\u009d') {
        this.beginControlString(1);
      } else if (character === '\u0090' || character === '\u009e' || character === '\u009f') {
        this.beginControlString(2);
      } else if (character === '\u001b') {
        this.parserState = 1;
      } else if (character === '\r') {
        this.cursorColumn = 0;
        this.wrapPending = false;
      } else if (character === '\n' || character === '\u000b' || character === '\u000c') {
        this.lineFeed();
      } else if (character === '\b') {
        this.cursorColumn = Math.max(0, this.cursorColumn - 1);
        this.wrapPending = false;
      } else if (character === '\t') {
        this.forwardTab();
      } else if (character === '\u000e') {
        this.activeCharset = 1;
      } else if (character === '\u000f') {
        this.activeCharset = 0;
      } else if (character >= ' ' && character !== '\u007f') {
        this.put(character);
      }
    }
  }

  render(): string {
    const lines: string[] = [];
    if (!this.alternateScreen) {
      this.history.forEach((line: TerminalCell[]) => lines.push(this.lineText(line)));
    }
    this.screen.forEach((line: TerminalCell[]) => lines.push(this.lineText(line)));
    while (lines.length > 0 && lines[lines.length - 1].length === 0) {
      lines.pop();
    }
    return lines.join('\n');
  }

  renderLines(): TerminalRenderLine[] {
    const result: TerminalRenderLine[] = [];
    if (!this.alternateScreen) {
      this.history.forEach((line: TerminalCell[]) => result.push(this.createRenderLine(line, -1)));
    }
    this.screen.forEach((line: TerminalCell[], row: number) => result.push(this.createRenderLine(line, row)));
    return result;
  }

  getTitle(): string {
    return this.title;
  }

  isBracketedPasteEnabled(): boolean {
    return this.bracketedPaste;
  }

  isApplicationCursorKeysEnabled(): boolean {
    return this.applicationCursorKeys;
  }

  drainResponses(): string {
    const pending: string = this.responses;
    this.responses = '';
    this.g0LineDrawing = false;
    this.g1LineDrawing = false;
    this.activeCharset = 0;
    this.charsetTarget = 0;
    return pending;
  }

  reset(): void {
    this.cursorRow = 0;
    this.cursorColumn = 0;
    this.savedRow = 0;
    this.savedColumn = 0;
    this.savedStyle = new TerminalStyle();
    this.currentStyle = new TerminalStyle();
    this.history = [];
    this.screen = [];
    this.primaryScreen = [];
    this.alternateScreen = false;
    this.autoWrap = true;
    this.insertMode = false;
    this.originMode = false;
    this.cursorVisible = true;
    this.applicationCursorKeys = false;
    this.bracketedPaste = false;
    this.wrapPending = false;
    this.scrollTop = 0;
    this.scrollBottom = this.rows - 1;
    this.title = '';
    this.responses = '';
    this.parserState = 0;
    this.csi = '';
    this.stringBuffer = '';
    this.stringKind = 0;
    this.resetTabStops();
    while (this.screen.length < this.rows) {
      this.screen.push(this.blankLine());
    }
  }

  private blankCell(style: TerminalStyle = new TerminalStyle()): TerminalCell {
    return new TerminalCell(' ', style, 1);
  }

  private blankLine(style: TerminalStyle = new TerminalStyle()): TerminalCell[] {
    const line: TerminalCell[] = [];
    for (let index: number = 0; index < this.columns; index++) {
      line.push(this.blankCell(style));
    }
    return line;
  }

  private resizeBuffer(buffer: TerminalCell[][], targetRows: number, addHistory: boolean): TerminalCell[][] {
    const result: TerminalCell[][] = buffer;
    result.forEach((line: TerminalCell[]) => this.resizeLine(line));
    while (result.length < targetRows) {
      result.push(this.blankLine());
    }
    while (result.length > targetRows) {
      const removed: TerminalCell[] = result.shift() as TerminalCell[];
      if (addHistory) this.history.push(this.copyLine(removed));
    }
    return result;
  }

  private resizeLine(line: TerminalCell[]): void {
    while (line.length < this.columns) line.push(this.blankCell());
    while (line.length > this.columns) line.pop();
    if (line.length > 0 && line[line.length - 1].width === 2) {
      line[line.length - 1] = this.blankCell();
    }
    if (line.length > 0 && line[line.length - 1].width === 0) {
      line[line.length - 1] = this.blankCell();
    }
    this.normalizeWideCells(line);
  }

  private copyLine(line: TerminalCell[]): TerminalCell[] {
    const result: TerminalCell[] = [];
    line.forEach((cell: TerminalCell) => result.push(cell.copy()));
    return result;
  }

  private lineText(line: TerminalCell[]): string {
    let end: number = line.length;
    while (end > 0 && (line[end - 1].width === 0 || line[end - 1].text === ' ')) end--;
    let result: string = '';
    for (let index: number = 0; index < end; index++) {
      if (line[index].width !== 0) result += line[index].text;
    }
    return result;
  }

  private trimHistory(): void {
    if (this.history.length > this.historyLimit) {
      this.history = this.history.slice(this.history.length - this.historyLimit);
    }
  }

  private resetTabStops(): void {
    this.tabStops = [];
    for (let index: number = 0; index < this.columns; index++) {
      this.tabStops.push(index > 0 && index % 8 === 0);
    }
  }

  private forwardTab(): void {
    let next: number = this.cursorColumn + 1;
    while (next < this.columns - 1 && !this.tabStops[next]) next++;
    this.cursorColumn = Math.min(this.columns - 1, next);
    this.wrapPending = false;
  }

  private lineFeed(): void {
    this.wrapPending = false;
    if (this.cursorRow === this.scrollBottom) {
      this.scrollUp(1);
    } else {
      this.cursorRow = Math.min(this.rows - 1, this.cursorRow + 1);
    }
  }

  private reverseIndex(): void {
    this.wrapPending = false;
    if (this.cursorRow === this.scrollTop) {
      this.scrollDown(1);
    } else {
      this.cursorRow = Math.max(0, this.cursorRow - 1);
    }
  }

  private scrollUp(amount: number): void {
    const count: number = Math.min(Math.max(1, amount), this.scrollBottom - this.scrollTop + 1);
    for (let index: number = 0; index < count; index++) {
      const removed: TerminalCell[] = this.screen.splice(this.scrollTop, 1)[0];
      if (!this.alternateScreen && this.scrollTop === 0 && this.scrollBottom === this.rows - 1) {
        this.history.push(this.copyLine(removed));
      }
      this.screen.splice(this.scrollBottom, 0, this.blankLine(this.currentStyle));
    }
    this.trimHistory();
  }

  private scrollDown(amount: number): void {
    const count: number = Math.min(Math.max(1, amount), this.scrollBottom - this.scrollTop + 1);
    for (let index: number = 0; index < count; index++) {
      this.screen.splice(this.scrollBottom, 1);
      this.screen.splice(this.scrollTop, 0, this.blankLine(this.currentStyle));
    }
  }

  private put(character: string): void {
    character = this.mapCharset(character);
    const width: number = this.characterWidth(character);
    if (width === 0) {
      this.appendCombining(character);
      return;
    }
    if (this.wrapPending) {
      if (this.autoWrap) {
        this.cursorColumn = 0;
        this.lineFeed();
      }
      this.wrapPending = false;
    }
    if (width === 2 && this.cursorColumn >= this.columns - 1) {
      if (this.autoWrap) {
        this.cursorColumn = 0;
        this.lineFeed();
      } else {
        return;
      }
    }
    if (this.insertMode) this.insertCharacters(width);
    this.clearWideCell(this.cursorRow, this.cursorColumn);
    this.screen[this.cursorRow][this.cursorColumn] = new TerminalCell(character, this.currentStyle, width);
    if (width === 2 && this.cursorColumn + 1 < this.columns) {
      this.clearWideCell(this.cursorRow, this.cursorColumn + 1);
      this.screen[this.cursorRow][this.cursorColumn + 1] = new TerminalCell('', this.currentStyle, 0);
    }
    const lastColumn: number = this.cursorColumn + width - 1;
    if (lastColumn >= this.columns - 1) {
      this.cursorColumn = this.columns - 1;
      this.wrapPending = this.autoWrap;
    } else {
      this.cursorColumn += width;
    }
  }

  private appendCombining(character: string): void {
    let row: number = this.cursorRow;
    let column: number = this.wrapPending ? this.cursorColumn : this.cursorColumn - 1;
    if (column < 0 && row > 0) {
      row--;
      column = this.columns - 1;
    }
    if (column < 0) return;
    while (column > 0 && this.screen[row][column].width === 0) column--;
    this.screen[row][column].text += character;
  }

  private characterWidth(character: string): number {
    const first: number = character.charCodeAt(0);
    let code: number = first;
    if (first >= 0xD800 && first <= 0xDBFF && character.length > 1) {
      const second: number = character.charCodeAt(1);
      code = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00);
    }
    if ((code >= 0x0300 && code <= 0x036F) || (code >= 0x1AB0 && code <= 0x1AFF) ||
      (code >= 0x1DC0 && code <= 0x1DFF) || (code >= 0x20D0 && code <= 0x20FF) ||
      (code >= 0xFE00 && code <= 0xFE0F) || (code >= 0xFE20 && code <= 0xFE2F)) return 0;
    if (code >= 0x1100 && (code <= 0x115F || code === 0x2329 || code === 0x232A ||
      (code >= 0x2E80 && code <= 0xA4CF && code !== 0x303F) || (code >= 0xAC00 && code <= 0xD7A3) ||
      (code >= 0xF900 && code <= 0xFAFF) || (code >= 0xFE10 && code <= 0xFE19) ||
      (code >= 0xFE30 && code <= 0xFE6F) || (code >= 0xFF00 && code <= 0xFF60) ||
      (code >= 0xFFE0 && code <= 0xFFE6) || (code >= 0x1F300 && code <= 0x1FAFF) ||
      (code >= 0x20000 && code <= 0x3FFFD))) return 2;
    return 1;
  }

  private clearWideCell(row: number, column: number): void {
    if (column < 0 || column >= this.columns) return;
    const cell: TerminalCell = this.screen[row][column];
    if (cell.width === 0 && column > 0) {
      this.screen[row][column - 1] = this.blankCell(this.currentStyle);
    } else if (cell.width === 2 && column + 1 < this.columns) {
      this.screen[row][column + 1] = this.blankCell(this.currentStyle);
    }
    this.screen[row][column] = this.blankCell(this.currentStyle);
  }

  private parameterValues(): number[] {
    let normalized: string = this.csi;
    while (normalized.length > 0 && '?><!'.indexOf(normalized.charAt(0)) >= 0) {
      normalized = normalized.substring(1);
    }
    const parts: string[] = normalized.split(';');
    const values: number[] = [];
    parts.forEach((part: string) => {
      const value: number = Number(part);
      values.push(part.length === 0 || Number.isNaN(value) ? -1 : value);
    });
    return values;
  }

  private parameter(index: number, fallback: number = 1): number {
    const values: number[] = this.parameterValues();
    if (index >= values.length || values[index] < 0) return fallback;
    return values[index];
  }

  private amountParameter(index: number = 0): number {
    return Math.max(1, this.parameter(index, 1));
  }

  private applyCsi(finalCharacter: string): void {
    const amount: number = this.amountParameter();
    if (finalCharacter === 'A') {
      this.cursorRow = Math.max(this.originMode ? this.scrollTop : 0, this.cursorRow - amount);
    } else if (finalCharacter === 'B') {
      this.cursorRow = Math.min(this.originMode ? this.scrollBottom : this.rows - 1, this.cursorRow + amount);
    } else if (finalCharacter === 'C' || finalCharacter === 'a') {
      this.cursorColumn = Math.min(this.columns - 1, this.cursorColumn + amount);
    } else if (finalCharacter === 'D') {
      this.cursorColumn = Math.max(0, this.cursorColumn - amount);
    } else if (finalCharacter === 'E') {
      this.cursorRow = Math.min(this.rows - 1, this.cursorRow + amount);
      this.cursorColumn = 0;
    } else if (finalCharacter === 'F') {
      this.cursorRow = Math.max(0, this.cursorRow - amount);
      this.cursorColumn = 0;
    } else if (finalCharacter === 'G' || finalCharacter === '`') {
      this.cursorColumn = Math.min(this.columns - 1, Math.max(0, amount - 1));
    } else if (finalCharacter === 'd') {
      const base: number = this.originMode ? this.scrollTop : 0;
      const bottom: number = this.originMode ? this.scrollBottom : this.rows - 1;
      this.cursorRow = Math.min(bottom, Math.max(base, base + amount - 1));
    } else if (finalCharacter === 'H' || finalCharacter === 'f') {
      const base: number = this.originMode ? this.scrollTop : 0;
      const bottom: number = this.originMode ? this.scrollBottom : this.rows - 1;
      this.cursorRow = Math.min(bottom, Math.max(base, base + this.parameter(0, 1) - 1));
      this.cursorColumn = Math.min(this.columns - 1, Math.max(0, this.parameter(1, 1) - 1));
    } else if (finalCharacter === 'J') {
      this.eraseInDisplay(this.parameter(0, 0));
    } else if (finalCharacter === 'K') {
      this.eraseInLine(this.parameter(0, 0));
    } else if (finalCharacter === '@') {
      this.insertCharacters(amount);
    } else if (finalCharacter === 'P') {
      this.deleteCharacters(amount);
    } else if (finalCharacter === 'X') {
      this.eraseCharacters(amount);
    } else if (finalCharacter === 'L') {
      this.insertLines(amount);
    } else if (finalCharacter === 'M') {
      this.deleteLines(amount);
    } else if (finalCharacter === 'S') {
      this.scrollUp(amount);
    } else if (finalCharacter === 'T') {
      this.scrollDown(amount);
    } else if (finalCharacter === 'r') {
      this.setScrollRegion();
    } else if (finalCharacter === 'm') {
      this.applySgr();
    } else if (finalCharacter === 'h' || finalCharacter === 'l') {
      this.setModes(finalCharacter === 'h');
    } else if (finalCharacter === 'g') {
      this.clearTabStops();
    } else if (finalCharacter === 'n') {
      this.reportStatus();
    } else if (finalCharacter === 'c') {
      this.responses += '\u001b[?1;2c';
    } else if (finalCharacter === 's') {
      this.saveCursor();
    } else if (finalCharacter === 'u') {
      this.restoreCursor();
    }
    if (finalCharacter !== 'm' && finalCharacter !== 'h' && finalCharacter !== 'l') {
      this.wrapPending = false;
    }
  }

  private applyEscape(character: string): void {
    if (character === '[') {
      this.parserState = 2;
      this.csi = '';
    } else if (character === ']') {
      this.beginControlString(1);
    } else if (character === 'P' || character === '^' || character === '_') {
      this.beginControlString(2);
    } else if (character === '7') {
      this.saveCursor();
      this.parserState = 0;
    } else if (character === '8') {
      this.restoreCursor();
      this.parserState = 0;
    } else if (character === 'D') {
      this.lineFeed();
      this.parserState = 0;
    } else if (character === 'M') {
      this.reverseIndex();
      this.parserState = 0;
    } else if (character === 'E') {
      this.cursorColumn = 0;
      this.lineFeed();
      this.parserState = 0;
    } else if (character === 'H') {
      this.tabStops[this.cursorColumn] = true;
      this.parserState = 0;
    } else if (character === 'c') {
      this.reset();
    } else if (character === '=') {
      this.parserState = 0;
    } else if (character === '>') {
      this.parserState = 0;
    } else if (character === '(' || character === ')' || character === '*' || character === '+') {
      this.charsetTarget = character === '(' ? 0 : (character === ')' ? 1 : (character === '*' ? 2 : 3));
      this.parserState = 5;
    } else {
      this.parserState = 0;
    }
  }

  private beginControlString(kind: number): void {
    this.stringKind = kind;
    this.stringBuffer = '';
    this.parserState = 3;
  }

  private finishControlString(): void {
    if (this.stringKind === 1) {
      const separator: number = this.stringBuffer.indexOf(';');
      if (separator >= 0) {
        const command: string = this.stringBuffer.substring(0, separator);
        if (command === '0' || command === '2') {
          this.title = this.sanitizeTitle(this.stringBuffer.substring(separator + 1));
        }
      }
    }
    this.stringBuffer = '';
    this.stringKind = 0;
    this.parserState = 0;
  }

  private eraseInDisplay(mode: number): void {
    if (mode === 0) {
      this.eraseRange(this.cursorRow, this.cursorColumn, this.columns);
      for (let row: number = this.cursorRow + 1; row < this.rows; row++) this.eraseRange(row, 0, this.columns);
    } else if (mode === 1) {
      for (let row: number = 0; row < this.cursorRow; row++) this.eraseRange(row, 0, this.columns);
      this.eraseRange(this.cursorRow, 0, this.cursorColumn + 1);
    } else if (mode === 2 || mode === 3) {
      for (let row: number = 0; row < this.rows; row++) this.eraseRange(row, 0, this.columns);
      if (mode === 3) this.history = [];
    }
  }

  private eraseInLine(mode: number): void {
    if (mode === 0) this.eraseRange(this.cursorRow, this.cursorColumn, this.columns);
    else if (mode === 1) this.eraseRange(this.cursorRow, 0, this.cursorColumn + 1);
    else if (mode === 2) this.eraseRange(this.cursorRow, 0, this.columns);
  }

  private eraseRange(row: number, start: number, end: number): void {
    for (let column: number = Math.max(0, start); column < Math.min(this.columns, end); column++) {
      this.clearWideCell(row, column);
      this.screen[row][column] = this.blankCell(this.currentStyle);
    }
  }

  private insertCharacters(amount: number): void {
    const count: number = Math.min(Math.max(1, amount), this.columns - this.cursorColumn);
    const line: TerminalCell[] = this.screen[this.cursorRow];
    for (let index: number = 0; index < count; index++) {
      line.splice(this.cursorColumn, 0, this.blankCell(this.currentStyle));
      line.pop();
    }
    this.normalizeWideCells(line);
  }

  private deleteCharacters(amount: number): void {
    const count: number = Math.min(Math.max(1, amount), this.columns - this.cursorColumn);
    const line: TerminalCell[] = this.screen[this.cursorRow];
    line.splice(this.cursorColumn, count);
    for (let index: number = 0; index < count; index++) line.push(this.blankCell(this.currentStyle));
    this.normalizeWideCells(line);
  }

  private eraseCharacters(amount: number): void {
    this.eraseRange(this.cursorRow, this.cursorColumn, this.cursorColumn + amount);
  }

  private insertLines(amount: number): void {
    if (this.cursorRow < this.scrollTop || this.cursorRow > this.scrollBottom) return;
    const count: number = Math.min(Math.max(1, amount), this.scrollBottom - this.cursorRow + 1);
    for (let index: number = 0; index < count; index++) {
      this.screen.splice(this.cursorRow, 0, this.blankLine(this.currentStyle));
      this.screen.splice(this.scrollBottom + 1, 1);
    }
  }

  private deleteLines(amount: number): void {
    if (this.cursorRow < this.scrollTop || this.cursorRow > this.scrollBottom) return;
    const count: number = Math.min(Math.max(1, amount), this.scrollBottom - this.cursorRow + 1);
    for (let index: number = 0; index < count; index++) {
      this.screen.splice(this.cursorRow, 1);
      this.screen.splice(this.scrollBottom, 0, this.blankLine(this.currentStyle));
    }
  }

  private normalizeWideCells(line: TerminalCell[]): void {
    for (let index: number = 0; index < line.length; index++) {
      if (line[index].width === 0 && (index === 0 || line[index - 1].width !== 2)) {
        line[index] = this.blankCell(this.currentStyle);
      } else if (line[index].width === 2 && (index + 1 >= line.length || line[index + 1].width !== 0)) {
        line[index] = this.blankCell(this.currentStyle);
      }
    }
  }

  private setScrollRegion(): void {
    const top: number = Math.max(0, this.parameter(0, 1) - 1);
    const bottom: number = Math.min(this.rows - 1, this.parameter(1, this.rows) - 1);
    if (top < bottom) {
      this.scrollTop = top;
      this.scrollBottom = bottom;
      this.cursorRow = this.originMode ? top : 0;
      this.cursorColumn = 0;
    }
  }

  private setModes(enabled: boolean): void {
    const privateMode: boolean = this.csi.startsWith('?');
    const values: number[] = this.parameterValues();
    values.forEach((mode: number) => {
      if (privateMode) {
        if (mode === 1) this.applicationCursorKeys = enabled;
        else if (mode === 6) {
          this.originMode = enabled;
          this.cursorRow = enabled ? this.scrollTop : 0;
          this.cursorColumn = 0;
        } else if (mode === 7) this.autoWrap = enabled;
        else if (mode === 25) this.cursorVisible = enabled;
        else if (mode === 47 || mode === 1047) this.setAlternateScreen(enabled, false);
        else if (mode === 1049) this.setAlternateScreen(enabled, true);
        else if (mode === 2004) this.bracketedPaste = enabled;
      } else if (mode === 4) {
        this.insertMode = enabled;
      }
    });
  }

  private setAlternateScreen(enabled: boolean, saveCursor: boolean): void {
    if (enabled && !this.alternateScreen) {
      if (saveCursor) this.saveCursor();
      this.primaryScreen = this.screen;
      this.primaryCursorRow = this.cursorRow;
      this.primaryCursorColumn = this.cursorColumn;
      this.screen = [];
      while (this.screen.length < this.rows) this.screen.push(this.blankLine());
      this.cursorRow = 0;
      this.cursorColumn = 0;
      this.alternateScreen = true;
    } else if (!enabled && this.alternateScreen) {
      this.screen = this.primaryScreen.length > 0 ? this.primaryScreen : this.screen;
      this.primaryScreen = [];
      this.cursorRow = Math.min(this.rows - 1, this.primaryCursorRow);
      this.cursorColumn = Math.min(this.columns - 1, this.primaryCursorColumn);
      this.alternateScreen = false;
      if (saveCursor) this.restoreCursor();
    }
    this.wrapPending = false;
  }

  private applySgr(): void {
    const values: number[] = this.parameterValues();
    if (values.length === 0) values.push(0);
    for (let index: number = 0; index < values.length; index++) {
      const code: number = values[index] < 0 ? 0 : values[index];
      if (code === 0) this.currentStyle = new TerminalStyle();
      else if (code === 1) this.currentStyle.bold = true;
      else if (code === 2) this.currentStyle.dim = true;
      else if (code === 3) this.currentStyle.italic = true;
      else if (code === 4) this.currentStyle.underline = true;
      else if (code === 7) this.currentStyle.inverse = true;
      else if (code === 8) this.currentStyle.hidden = true;
      else if (code === 9) this.currentStyle.strikeThrough = true;
      else if (code === 22) {
        this.currentStyle.bold = false;
        this.currentStyle.dim = false;
      } else if (code === 23) this.currentStyle.italic = false;
      else if (code === 24) this.currentStyle.underline = false;
      else if (code === 27) this.currentStyle.inverse = false;
      else if (code === 28) this.currentStyle.hidden = false;
      else if (code === 29) this.currentStyle.strikeThrough = false;
      else if (code >= 30 && code <= 37) this.currentStyle.foreground = ANSI_COLORS[code - 30];
      else if (code === 39) this.currentStyle.foreground = DEFAULT_FOREGROUND;
      else if (code >= 40 && code <= 47) this.currentStyle.background = ANSI_COLORS[code - 40];
      else if (code === 49) this.currentStyle.background = DEFAULT_BACKGROUND;
      else if (code >= 90 && code <= 97) this.currentStyle.foreground = ANSI_COLORS[code - 90 + 8];
      else if (code >= 100 && code <= 107) this.currentStyle.background = ANSI_COLORS[code - 100 + 8];
      else if ((code === 38 || code === 48) && index + 1 < values.length) {
        const colorResult: string[] = this.extendedColor(values, index + 1);
        if (colorResult.length === 2) {
          if (code === 38) this.currentStyle.foreground = colorResult[0];
          else this.currentStyle.background = colorResult[0];
          index = Number(colorResult[1]);
        }
      }
    }
  }

  private extendedColor(values: number[], modeIndex: number): string[] {
    const mode: number = values[modeIndex];
    if (mode === 5 && modeIndex + 1 < values.length) {
      const colorIndex: number = this.clamp(values[modeIndex + 1], 0, 255);
      return [this.xtermColor(colorIndex), (modeIndex + 1).toString()];
    }
    if (mode === 2 && modeIndex + 3 < values.length) {
      const red: number = this.clamp(values[modeIndex + 1], 0, 255);
      const green: number = this.clamp(values[modeIndex + 2], 0, 255);
      const blue: number = this.clamp(values[modeIndex + 3], 0, 255);
      return [this.rgbColor(red, green, blue), (modeIndex + 3).toString()];
    }
    return [];
  }

  private xtermColor(index: number): string {
    if (index < 16) return ANSI_COLORS[index];
    if (index >= 232) {
      const value: number = 8 + (index - 232) * 10;
      return this.rgbColor(value, value, value);
    }
    const adjusted: number = index - 16;
    const red: number = Math.floor(adjusted / 36);
    const green: number = Math.floor((adjusted % 36) / 6);
    const blue: number = adjusted % 6;
    const component: number[] = [0, 95, 135, 175, 215, 255];
    return this.rgbColor(component[red], component[green], component[blue]);
  }

  private rgbColor(red: number, green: number, blue: number): string {
    return '#' + this.hex(red) + this.hex(green) + this.hex(blue);
  }

  private hex(value: number): string {
    const result: string = this.clamp(value, 0, 255).toString(16).toUpperCase();
    return result.length < 2 ? '0' + result : result;
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.min(maximum, Math.max(minimum, value));
  }

  private clearTabStops(): void {
    const mode: number = this.parameter(0, 0);
    if (mode === 0) this.tabStops[this.cursorColumn] = false;
    else if (mode === 3) {
      for (let index: number = 0; index < this.tabStops.length; index++) this.tabStops[index] = false;
    }
  }

  private reportStatus(): void {
    const mode: number = this.parameter(0, 0);
    if (mode === 5) this.responses += '\u001b[0n';
    else if (mode === 6) {
      const row: number = this.originMode ? this.cursorRow - this.scrollTop + 1 : this.cursorRow + 1;
      this.responses += '\u001b[' + row.toString() + ';' + (this.cursorColumn + 1).toString() + 'R';
    }
  }

  private sanitizeTitle(value: string): string {
    let result: string = '';
    for (let index: number = 0; index < value.length && result.length < 256; index++) {
      const code: number = value.charCodeAt(index);
      if (code >= 0x20 && code !== 0x7F) result += value.charAt(index);
    }
    return result;
  }

  private mapCharset(character: string): string {
    const lineDrawing: boolean = this.activeCharset === 0 ? this.g0LineDrawing : this.g1LineDrawing;
    if (!lineDrawing || character.length !== 1) return character;
    if (character === '`') return '\u25C6';
    if (character === 'a') return '\u2592';
    if (character === 'f') return '\u00B0';
    if (character === 'g') return '\u00B1';
    if (character === 'h') return '\u2424';
    if (character === 'j') return '\u2518';
    if (character === 'k') return '\u2510';
    if (character === 'l') return '\u250C';
    if (character === 'm') return '\u2514';
    if (character === 'n') return '\u253C';
    if (character === 'o') return '\u23BA';
    if (character === 'p') return '\u23BB';
    if (character === 'q') return '\u2500';
    if (character === 'r') return '\u23BC';
    if (character === 's') return '\u23BD';
    if (character === 't') return '\u251C';
    if (character === 'u') return '\u2524';
    if (character === 'v') return '\u2534';
    if (character === 'w') return '\u252C';
    if (character === 'x') return '\u2502';
    if (character === 'y') return '\u2264';
    if (character === 'z') return '\u2265';
    if (character === '{') return '\u03C0';
    if (character === '|') return '\u2260';
    if (character === '}') return '\u00A3';
    if (character === '~') return '\u00B7';
    return character;
  }

  private saveCursor(): void {
    this.savedRow = this.cursorRow;
    this.savedColumn = this.cursorColumn;
    this.savedStyle = this.currentStyle.copy();
  }

  private restoreCursor(): void {
    this.cursorRow = Math.min(this.rows - 1, Math.max(0, this.savedRow));
    this.cursorColumn = Math.min(this.columns - 1, Math.max(0, this.savedColumn));
    this.currentStyle = this.savedStyle.copy();
    this.wrapPending = false;
  }

  private createRenderLine(line: TerminalCell[], screenRow: number): TerminalRenderLine {
    let end: number = line.length;
    const minimum: number = screenRow === this.cursorRow && this.cursorVisible ? this.cursorColumn + 1 : 0;
    while (end > minimum && line[end - 1].width === 1 && line[end - 1].text === ' ' &&
      line[end - 1].style.background === DEFAULT_BACKGROUND) end--;
    const runs: TerminalRenderRun[] = [];
    for (let column: number = 0; column < end && column < line.length; column++) {
      const cell: TerminalCell = line[column];
      if (cell.width === 0) continue;
      const cursor: boolean = screenRow === this.cursorRow && this.cursorVisible && column === this.cursorColumn;
      const foreground: string = this.resolvedForeground(cell.style, cursor);
      const background: string = this.resolvedBackground(cell.style, cursor);
      const text: string = cursor ? '|' : (cell.style.hidden ? ' ' : cell.text);
      const previous: TerminalRenderRun | undefined = runs.length > 0 ? runs[runs.length - 1] : undefined;
      if (previous !== undefined && previous.foreground === foreground && previous.background === background &&
        previous.cursor === cursor &&
        previous.bold === cell.style.bold && previous.dim === cell.style.dim && previous.italic === cell.style.italic &&
        previous.underline === cell.style.underline && previous.strikeThrough === cell.style.strikeThrough) {
        previous.text += text;
      } else {
        runs.push(new TerminalRenderRun(text, foreground, background, cell.style.bold, cell.style.dim,
          cell.style.italic, cell.style.underline, cell.style.strikeThrough, cursor));
      }
    }
    return new TerminalRenderLine(runs);
  }

  private resolvedForeground(style: TerminalStyle, cursor: boolean): string {
    const foreground: string = style.inverse ? style.background : style.foreground;
    const background: string = style.inverse ? style.foreground : style.background;
    return cursor ? background : foreground;
  }

  private resolvedBackground(style: TerminalStyle, cursor: boolean): string {
    const foreground: string = style.inverse ? style.background : style.foreground;
    const background: string = style.inverse ? style.foreground : style.background;
    return cursor ? foreground : background;
  }
}
