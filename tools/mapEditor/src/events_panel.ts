import {
  dialogLinesOf,
  eventTypeOf,
  newEvent,
  nextEventId,
  placeEvent,
  setDialogLines,
  type MvEvent,
} from './mvmap';
import type { EditorState } from './state';

const TYPE_BADGE_COLORS: Record<string, string> = {
  TALK: '#f050dc',
  SIGN: '#3cdce6',
  EVENT: '#5ae65a',
  ENTER: '#f0dc3c',
  NPC: '#f09040',
  UNKNOWN: '#aaaaaa',
};

const HADAR_KINDS = ['(없음)', 'talk', 'sign', 'warp', 'oneshot'];

/**
 * 이벤트 목록 + 인스펙터.
 * MV 이벤트의 모든 필드를 보존하고, 이 툴이 만지는 것은
 * name / note / x / y / 대사(code 401) / hadarEvent 확장뿐이다.
 */
export class EventsPanel {
  constructor(
    private root: HTMLElement,
    private state: EditorState,
    /** 스냅샷 undo 로 감싸서 실행 (before → fn → commit → 화면 갱신). */
    private mutate: (fn: () => void) => void,
    private requestRender: () => void,
  ) {}

  refresh(): void {
    const map = this.state.map;
    this.root.innerHTML = '';
    if (!map) return;

    // 새 이벤트 만들기
    const createRow = document.createElement('div');
    createRow.className = 'row';
    const typeSel = document.createElement('select');
    for (const t of ['TALK', 'SIGN', 'EVENT', 'ENTER', 'NPC']) {
      const opt = document.createElement('option');
      opt.value = t;
      opt.textContent = t;
      typeSel.appendChild(opt);
    }
    const addBtn = document.createElement('button');
    addBtn.textContent = '새 이벤트';
    addBtn.onclick = () => this.createEvent(typeSel.value);
    createRow.append(typeSel, addBtn);
    this.root.appendChild(createRow);

    // 목록
    const list = document.createElement('div');
    list.id = 'eventList';
    for (const ev of map.events) {
      if (!ev) continue;
      const type = eventTypeOf(ev.name);
      const row = document.createElement('div');
      row.className = 'evRow' + (this.state.selectedEventId === ev.id ? ' sel' : '');
      const badge = document.createElement('span');
      badge.className = 'evBadge';
      badge.textContent = type;
      badge.style.background = TYPE_BADGE_COLORS[type] ?? TYPE_BADGE_COLORS.UNKNOWN;
      const name = document.createElement('span');
      name.className = 'evName';
      name.textContent = ev.name + (ev.note ? ` — ${ev.note}` : '');
      const pos = document.createElement('span');
      pos.className = 'evPos';
      pos.textContent = `(${ev.x},${ev.y})`;
      row.append(badge, name, pos);
      row.onclick = () => {
        this.state.selectedEventId = ev.id;
        this.centerOn(ev);
        this.refresh();
        this.requestRender();
      };
      list.appendChild(row);
    }
    this.root.appendChild(list);

    // 인스펙터
    const selected = this.selectedEvent();
    if (selected) this.buildInspector(selected);
  }

  private selectedEvent(): MvEvent | null {
    const map = this.state.map;
    const id = this.state.selectedEventId;
    if (!map || id === null) return null;
    return map.events[id] ?? null;
  }

  private buildInspector(ev: MvEvent): void {
    const box = document.createElement('div');

    const field = (label: string, el: HTMLElement) => {
      const wrap = document.createElement('div');
      wrap.className = 'field';
      const span = document.createElement('span');
      span.textContent = label;
      wrap.append(span, el);
      return wrap;
    };

    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.value = ev.name;
    nameInput.style.width = '100%';
    box.appendChild(
      field('이름 (접두사가 타입 결정: TALK/SIGN/EVENT/ENTER/NPC)', nameInput),
    );

    const noteInput = document.createElement('input');
    noteInput.type = 'text';
    noteInput.value = ev.note;
    noteInput.style.width = '100%';
    box.appendChild(field('메모 (note)', noteInput));

    const posRow = document.createElement('div');
    posRow.className = 'row';
    const xInput = document.createElement('input');
    xInput.type = 'number';
    xInput.className = 'num';
    xInput.value = String(ev.x);
    const yInput = document.createElement('input');
    yInput.type = 'number';
    yInput.className = 'num';
    yInput.value = String(ev.y);
    posRow.append('x', xInput, 'y', yInput);
    box.appendChild(field('위치 (이벤트 모드에서 빈 타일 클릭으로도 이동)', posRow));

    const dialogTa = document.createElement('textarea');
    dialogTa.rows = 4;
    dialogTa.value = dialogLinesOf(ev).join('\n');
    box.appendChild(field('대사 (한 줄 = code 401 한 줄)', dialogTa));

    const kindSel = document.createElement('select');
    for (const k of HADAR_KINDS) {
      const opt = document.createElement('option');
      opt.value = k;
      opt.textContent = k;
      kindSel.appendChild(opt);
    }
    kindSel.value = ev.hadarEvent?.kind && HADAR_KINDS.includes(ev.hadarEvent.kind)
      ? ev.hadarEvent.kind
      : '(없음)';
    box.appendChild(field('hadarEvent 확장 kind', kindSel));

    const payloadTa = document.createElement('textarea');
    payloadTa.rows = 3;
    payloadTa.value = ev.hadarEvent ? JSON.stringify(ev.hadarEvent.payload ?? {}) : '{}';
    payloadTa.placeholder = 'warp: {"map":"TOWN1","x":10,"y":20} / oneshot: {"flag":3}';
    box.appendChild(field('hadarEvent payload (JSON)', payloadTa));

    const btnRow = document.createElement('div');
    btnRow.className = 'row';
    const applyBtn = document.createElement('button');
    applyBtn.textContent = '적용';
    applyBtn.onclick = () => {
      let payload: Record<string, unknown> = {};
      if (kindSel.value !== '(없음)') {
        try {
          payload = JSON.parse(payloadTa.value || '{}');
        } catch (e) {
          alert(`payload JSON 파싱 실패: ${e}`);
          return;
        }
      }
      const map = this.state.map!;
      this.mutate(() => {
        ev.name = nameInput.value;
        ev.note = noteInput.value;
        ev.x = clamp(Number(xInput.value) || 0, 0, map.width - 1);
        ev.y = clamp(Number(yInput.value) || 0, 0, map.height - 1);
        // 텍스트가 원문 그대로면 손대지 않는다 — 중간 빈 줄이 있는 이벤트를
        // '적용'만 눌러도 페이지 커맨드가 재구성되던 문제를 막는다.
        if (dialogTa.value !== dialogLinesOf(ev).join('\n')) {
          const lines = dialogTa.value.split('\n');
          // 끝의 빈 줄만 정리하고 중간 빈 줄은 대사로 보존
          while (lines.length > 0 && lines[lines.length - 1] === '') lines.pop();
          setDialogLines(ev, lines);
        }
        if (kindSel.value === '(없음)') {
          delete ev.hadarEvent;
        } else {
          ev.hadarEvent = { kind: kindSel.value, payload };
        }
      });
      this.refresh();
    };
    const deleteBtn = document.createElement('button');
    deleteBtn.textContent = '삭제';
    deleteBtn.onclick = () => {
      if (!confirm(`이벤트 ${ev.name} (id ${ev.id}) 를 삭제할까요?`)) return;
      this.mutate(() => {
        this.state.map!.events[ev.id] = null;
        this.state.selectedEventId = null;
      });
      this.refresh();
    };
    btnRow.append(applyBtn, deleteBtn);
    box.appendChild(btnRow);

    this.root.appendChild(box);
  }

  private createEvent(typePrefix: string): void {
    const map = this.state.map;
    if (!map) return;
    // 접두사별 다음 번호 (TALK001 스타일)
    let maxNum = 0;
    for (const e of map.events) {
      if (!e || !e.name.startsWith(typePrefix)) continue;
      const n = parseInt(e.name.slice(typePrefix.length), 10);
      if (!Number.isNaN(n)) maxNum = Math.max(maxNum, n);
    }
    const name = `${typePrefix}${String(maxNum + 1).padStart(3, '0')}`;
    const id = nextEventId(map);
    // 화면 중앙 근처에 생성 (이후 클릭으로 이동)
    const x = clamp(this.state.hoverX >= 0 ? this.state.hoverX : Math.floor(map.width / 2), 0, map.width - 1);
    const y = clamp(this.state.hoverY >= 0 ? this.state.hoverY : Math.floor(map.height / 2), 0, map.height - 1);
    this.mutate(() => {
      const ev = newEvent(id, name, x, y);
      placeEvent(map, ev);
      this.state.selectedEventId = id;
    });
    this.refresh();
  }

  private centerOn(ev: MvEvent): void {
    // 이벤트가 화면 밖이면 화면 중앙으로 팬 이동
    const canvas = document.getElementById('mapCanvas') as HTMLCanvasElement | null;
    if (!canvas) return;
    const ts = 32 * this.state.zoom;
    const sx = this.state.panX + ev.x * ts;
    const sy = this.state.panY + ev.y * ts;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (sx < 0 || sy < 0 || sx > w - ts || sy > h - ts) {
      this.state.panX = w / 2 - ev.x * ts;
      this.state.panY = h / 2 - ev.y * ts;
    }
  }
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}
