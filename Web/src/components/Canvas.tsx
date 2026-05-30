import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { RotateCcw, Hand, Orbit, ZoomIn, ZoomOut, Box, Maximize2 } from "lucide-react";
import type { ViewNode } from "../protocol";
import { Flag, hasFlag } from "../protocol";
import { kindColor } from "../store";
import type { Inspector } from "../hooks/useInspector";
import { Slider } from "./ui/slider";
import { Button } from "./ui/button";

interface Flat { node: ViewNode; depth: number; }

const DEFAULT_ROT = { x: 18, y: -22 };
const DEFAULT_SPACING = 26;
const ZOOM_MIN = 0.1;
const ZOOM_MAX = 6;
// Wheel-zoom tuning (Figma/tldraw model): clamp deltaY so a mouse wheel's big discrete
// ticks (~100+) and a trackpad pinch's tiny deltas (~0.5–3) produce a similar zoom step.
const ZOOM_WHEEL_CLAMP = 10;
const ZOOM_WHEEL_SENS = 0.01;

export function Canvas({ insp }: { insp: Inspector }) {
  const { state, select, hover, client } = insp;
  const { options } = state;
  const viewportRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 800, h: 600 });
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [rot, setRot] = useState(DEFAULT_ROT);
  const [spacing, setSpacing] = useState(DEFAULT_SPACING);
  const drag = useRef<{ x: number; y: number; px: number; py: number; rx: number; ry: number; mode: "pan" | "orbit"; moved: boolean; downId?: string } | null>(null);
  const wheelFn = useRef<(e: WheelEvent) => void>();

  useLayoutEffect(() => {
    const el = viewportRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }));
    ro.observe(el);
    setSize({ w: el.clientWidth, h: el.clientHeight });
    return () => ro.disconnect();
  }, []);

  // Native, non-passive wheel listener: React's onWheel is passive, so preventDefault()
  // there can't stop pinch gestures from triggering browser page-zoom. We dispatch through
  // a ref so the handler always sees fresh render state, and re-bind when the snapshot
  // arrives — the viewport div only mounts once there's content to show.
  const hasContent = !!state.snapshot && state.snapshot.roots.length > 0;
  useEffect(() => {
    const el = viewportRef.current;
    if (!el) return;
    const h = (e: WheelEvent) => wheelFn.current?.(e);
    el.addEventListener("wheel", h, { passive: false });
    return () => el.removeEventListener("wheel", h);
  }, [hasContent]);

  useEffect(() => { setPan({ x: 0, y: 0 }); }, [state.snapshot]);

  const { flat, maxX, maxY } = useMemo(() => {
    const f: Flat[] = [];
    let mx = 1, my = 1;
    const walk = (n: ViewNode, depth: number) => {
      f.push({ node: n, depth });
      mx = Math.max(mx, n.frame.x + n.frame.width);
      my = Math.max(my, n.frame.y + n.frame.height);
      n.children.forEach((c) => walk(c, depth + 1));
    };
    state.snapshot?.roots.forEach((r) => walk(r, 0));
    return { flat: f, maxX: mx, maxY: my };
  }, [state.snapshot]);

  const fit = Math.min(size.w / maxX, size.h / maxY) * 0.82 || 1;
  const baseScale = Math.max(0.05, fit);
  const scale = baseScale * zoom;

  // Zoom toward a screen point (cursor). In 2D we keep the point under the cursor fixed;
  // in 3D the rotated transform makes that math unreliable, so we zoom about the center.
  const zoomTo = (next: number, clientX?: number, clientY?: number) => {
    const z = clamp(next, ZOOM_MIN, ZOOM_MAX);
    const el = viewportRef.current;
    if (el && !options.exploded && clientX != null && clientY != null) {
      const r = el.getBoundingClientRect();
      const mx = clientX - r.left, my = clientY - r.top;
      const s0 = scale, s1 = baseScale * z;
      const cx = (mx - (size.w - maxX * s0) / 2 - pan.x) / s0;
      const cy = (my - (size.h - maxY * s0) / 2 - pan.y) / s0;
      setPan({ x: mx - (size.w - maxX * s1) / 2 - cx * s1, y: my - (size.h - maxY * s1) / 2 - cy * s1 });
    }
    setZoom(z);
  };

  const resetView = () => {
    setPan({ x: 0, y: 0 });
    setZoom(1);
    setRot(DEFAULT_ROT);
    setSpacing(DEFAULT_SPACING);
  };

  wheelFn.current = (e: WheelEvent) => {
    e.preventDefault();
    // Figma/tldraw model, unified for 2D and 3D: the browser reports a trackpad pinch (and
    // ⌘/Ctrl+wheel) via ctrlKey/metaKey → zoom toward the cursor; everything else — a two-finger
    // trackpad swipe or a plain mouse wheel — pans. So sideways/vertical swipes always move the view.
    if (e.ctrlKey || e.metaKey) {
      const dz = clamp(e.deltaY, -ZOOM_WHEEL_CLAMP, ZOOM_WHEEL_CLAMP);
      zoomTo(zoom * Math.pow(2, -dz * ZOOM_WHEEL_SENS), e.clientX, e.clientY);
    } else {
      // Two-finger swipe pans both axes; ⇧ maps a vertical mouse wheel to horizontal.
      const horiz = e.shiftKey && e.deltaX === 0;
      setPan((p) => ({ x: p.x - (horiz ? e.deltaY : e.deltaX), y: p.y - (horiz ? 0 : e.deltaY) }));
    }
  };

  // Focus (F / toolbar): center + zoom the selected node.
  const focusedRef = useRef(insp.focusSignal);
  useEffect(() => {
    if (insp.focusSignal === focusedRef.current) return;
    focusedRef.current = insp.focusSignal;
    const node = insp.selected;
    if (!node || node.frame.width < 1 || node.frame.height < 1) return;
    const targetZoom = clamp(Math.min(size.w / (node.frame.width * baseScale), size.h / (node.frame.height * baseScale)) * 0.55, 0.2, 6);
    setZoom(targetZoom);
    const s = baseScale * targetZoom;
    const cx = node.frame.x + node.frame.width / 2;
    const cy = node.frame.y + node.frame.height / 2;
    setPan({
      x: size.w / 2 - cx * s - (size.w - maxX * s) / 2,
      y: size.h / 2 - cy * s - (size.h - maxY * s) / 2,
    });
  }, [insp.focusSignal]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!state.snapshot || state.snapshot.roots.length === 0) {
    return <div className="h-full bg-[radial-gradient(circle_at_50%_40%,#232327,#161618)]" />;
  }

  const baseLeft = (size.w - maxX * scale) / 2 + pan.x;
  const baseTop = (size.h - maxY * scale) / 2 + pan.y;
  const explodeStep = options.exploded ? spacing : 0;

  const bg = options.showSnapshots
    ? [...flat].filter((f) => f.node.snapshotID).sort((a, b) => area(b.node) - area(a.node))[0]
    : undefined;

  // Drag anywhere to pan (or orbit in 3D); a press that doesn't move past the
  // threshold is treated as a tap and selects the node under the cursor.
  const TAP_SLOP = 4;
  const onPointerDown = (e: React.PointerEvent) => {
    // Don't hijack presses on the overlay controls (zoom/angle/reset, sliders) — they
    // capture the pointer and would otherwise swallow the control's own click.
    if ((e.target as HTMLElement).closest("[data-canvas-control]")) return;
    const downId = (e.target as HTMLElement).closest("[data-id]")?.getAttribute("data-id") ?? undefined;
    const mode: "pan" | "orbit" = options.exploded && !e.altKey && !e.shiftKey ? "orbit" : "pan";
    drag.current = { x: e.clientX, y: e.clientY, px: pan.x, py: pan.y, rx: rot.x, ry: rot.y, mode, moved: false, downId };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };
  const onPointerMove = (e: React.PointerEvent) => {
    const d = drag.current;
    if (!d) return;
    const dx = e.clientX - d.x, dy = e.clientY - d.y;
    if (!d.moved && Math.hypot(dx, dy) < TAP_SLOP) return;
    d.moved = true;
    if (d.mode === "orbit") setRot({ x: clamp(d.rx - dy * 0.4, -85, 85), y: d.ry + dx * 0.4 });
    else setPan({ x: d.px + dx, y: d.py + dy });
  };
  const onPointerUp = () => {
    const d = drag.current;
    drag.current = null;
    if (d && !d.moved && d.downId) select(d.downId);
  };

  const transform = `translate(${baseLeft}px, ${baseTop}px) scale(${scale}) ` +
    (options.exploded ? `rotateX(${rot.x}deg) rotateY(${rot.y}deg)` : "");

  return (
    <div
      ref={viewportRef}
      className="relative h-full select-none overflow-hidden bg-[radial-gradient(circle_at_50%_40%,#232327,#161618)]"
      style={{ perspective: 1600, cursor: drag.current?.moved ? "grabbing" : "grab" }}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onDoubleClick={resetView}
    >
      <div
        className="absolute origin-top-left"
        style={{ width: maxX, height: maxY, transformStyle: "preserve-3d", transform, transition: drag.current ? "none" : "transform 0.25s ease" }}
      >
        {bg && (
          <img src={client.snapshotURL(bg.node.snapshotID!)} className="pointer-events-none absolute" alt=""
            style={{ left: bg.node.frame.x, top: bg.node.frame.y, width: bg.node.frame.width, height: bg.node.frame.height, opacity: options.exploded ? 0.6 : 0.95 }} />
        )}
        {flat.map(({ node, depth }) => {
          if (node.frame.width < 0.5 || node.frame.height < 0.5) return null;
          const selected = node.id === state.selectedID;
          const hovered = node.id === state.hoveredID;
          const accent = kindColor(node.kind);
          return (
            <div key={node.id} data-id={node.id} className="absolute"
              style={{
                left: node.frame.x, top: node.frame.y, width: node.frame.width, height: node.frame.height,
                transform: explodeStep ? `translateZ(${depth * explodeStep}px)` : undefined,
                transition: drag.current ? "none" : "transform 0.25s ease",
                border: selected ? `2px solid ${accent}` : hovered ? `1.5px solid ${accent}` : options.showWireframe ? `1px solid ${accent}88` : "1px solid transparent",
                background: selected ? `${accent}22` : options.exploded ? `${accent}10` : hovered ? `${accent}14` : "transparent",
                opacity: hasFlag(node, Flag.hidden) ? 0.35 : 1,
                zIndex: selected ? 9999 : hovered ? 9998 : undefined,
                boxShadow: options.exploded ? "0 1px 8px rgba(0,0,0,0.35)" : undefined,
              }}
              onMouseEnter={() => hover(node.id)}
              onMouseLeave={() => hover(undefined)}
            >
              {selected && options.showSnapshots && node.snapshotID && (
                <img src={client.snapshotURL(node.snapshotID)} className="pointer-events-none h-full w-full" alt="" />
              )}
            </div>
          );
        })}
      </div>

      {options.exploded && (
        <div data-canvas-control className="absolute bottom-3 left-1/2 flex -translate-x-1/2 items-center gap-3 rounded-lg border border-border/60 bg-card/80 px-3 py-2 backdrop-blur-md">
          <Orbit className="h-3.5 w-3.5 text-muted-foreground" />
          <AngleSlider label="X" value={rot.x} min={-85} max={85} onChange={(x) => setRot((r) => ({ ...r, x }))} />
          <AngleSlider label="Y" value={rot.y} min={-180} max={180} onChange={(y) => setRot((r) => ({ ...r, y }))} />
          <div className="flex items-center gap-1.5">
            <span className="text-[10px] text-muted-foreground">depth</span>
            <Slider className="w-20" value={[spacing]} min={4} max={80} step={1} onValueChange={([v]) => setSpacing(v)} />
          </div>
          <Button variant="ghost" size="icon" className="h-6 w-6" title="Reset angle" onClick={() => { setRot(DEFAULT_ROT); setSpacing(DEFAULT_SPACING); }}>
            <RotateCcw className="h-3.5 w-3.5" />
          </Button>
        </div>
      )}

      {/* Floating viewport controls — zoom, 3D angle, reset. */}
      <div data-canvas-control className="absolute bottom-3 right-3 flex flex-col items-center gap-0.5 rounded-lg border border-border/60 bg-card/80 p-1 backdrop-blur-md">
        <CtrlBtn title="Zoom in (⌘-scroll)" onClick={() => zoomTo(zoom * 1.2)}><ZoomIn className="h-4 w-4" /></CtrlBtn>
        <button
          className="w-9 rounded py-0.5 text-center font-mono text-[10px] text-muted-foreground hover:bg-secondary hover:text-foreground"
          title="Reset zoom to 100%"
          onClick={() => setZoom(1)}
        >
          {Math.round(zoom * 100)}%
        </button>
        <CtrlBtn title="Zoom out" onClick={() => zoomTo(zoom / 1.2)}><ZoomOut className="h-4 w-4" /></CtrlBtn>
        <div className="my-0.5 h-px w-5 bg-border/60" />
        <CtrlBtn title="Toggle 3D angle" active={options.exploded} onClick={() => insp.setOption("exploded", !options.exploded)}>
          <Box className="h-4 w-4" />
        </CtrlBtn>
        <CtrlBtn title="Fit to screen" onClick={() => { setPan({ x: 0, y: 0 }); setZoom(1); }}><Maximize2 className="h-4 w-4" /></CtrlBtn>
        <CtrlBtn title="Reset view (double-click)" onClick={resetView}><RotateCcw className="h-4 w-4" /></CtrlBtn>
      </div>

      <div className="pointer-events-none absolute right-3 top-3 flex items-center gap-1 rounded-md bg-card/70 px-2 py-1 text-[10px] text-muted-foreground backdrop-blur">
        {options.exploded
          ? <><Orbit className="h-3 w-3" /> drag to orbit · scroll or ⌥-drag to pan · pinch / ⌘-scroll to zoom</>
          : <><Hand className="h-3 w-3" /> drag or scroll to pan · pinch / ⌘-scroll to zoom</>}
      </div>
    </div>
  );
}

function CtrlBtn({ title, active, onClick, children }: { title: string; active?: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      title={title}
      onClick={onClick}
      className={
        "flex h-7 w-7 items-center justify-center rounded transition-colors " +
        (active ? "bg-primary/20 text-primary" : "text-muted-foreground hover:bg-secondary hover:text-foreground")
      }
    >
      {children}
    </button>
  );
}

function AngleSlider({ label, value, min, max, onChange }: { label: string; value: number; min: number; max: number; onChange: (v: number) => void }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="w-2 text-[10px] text-muted-foreground">{label}</span>
      <Slider className="w-20" value={[value]} min={min} max={max} step={1} onValueChange={([v]) => onChange(v)} />
      <span className="w-7 text-right font-mono text-[10px] text-muted-foreground">{Math.round(value)}°</span>
    </div>
  );
}

function area(n: ViewNode): number { return n.frame.width * n.frame.height; }
function clamp(v: number, lo: number, hi: number): number { return Math.max(lo, Math.min(hi, v)); }
