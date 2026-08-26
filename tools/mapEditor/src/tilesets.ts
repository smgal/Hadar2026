// 타일 시트 이미지 로딩 (브라우저 전용). 좌표 변환/액션 규칙은 rules.ts 에 있고,
// 기존 임포트 호환을 위해 재수출한다.
import { a5Rect, bRect, type SheetRect } from './rules';

export * from './rules';

export class Tilesets {
  a5!: HTMLImageElement;
  b!: HTMLImageElement;

  async load(): Promise<void> {
    [this.a5, this.b] = await Promise.all([
      loadImage('/api/image?file=Lore_A5.png'),
      loadImage('/api/image?file=Lore_B.png'),
    ]);
  }

  a5Rect(raw: number): SheetRect | null {
    return a5Rect(raw);
  }

  bRect(id: number): SheetRect | null {
    return bRect(id);
  }
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error(`이미지 로드 실패: ${src}`));
    img.src = src;
  });
}
