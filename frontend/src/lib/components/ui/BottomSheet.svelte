<script lang="ts">
	type Props = {
		isOpen?: boolean;
		initialHeight?: string;
		expandedHeight?: string;
		peekHeight?: string;
		children?: import('svelte').Snippet;
		onToggle?: () => void;
		class?: string;
	};

	let {
		isOpen = $bindable(false),
		initialHeight = '35vh',
		expandedHeight = '92vh',
		peekHeight = '4.8rem',
		children,
		class: className = ''
	}: Props = $props();

	type Snap = 'collapsed' | 'mid' | 'full';

	let snap = $state<Snap>('collapsed');
	let isDragging = $state(false);
	let dragVisiblePx = $state<number | null>(null);
	let startY = 0;
	let startVisiblePx = 0;

	const rootFontSize = () =>
		typeof window === 'undefined'
			? 16
			: Number.parseFloat(getComputedStyle(document.documentElement).fontSize || '16');

	const toPx = (value: string) => {
		if (typeof window === 'undefined') return 0;
		const input = value.trim();
		if (input.endsWith('vh')) return (Number.parseFloat(input) / 100) * window.innerHeight;
		if (input.endsWith('rem')) return Number.parseFloat(input) * rootFontSize();
		if (input.endsWith('px')) return Number.parseFloat(input);
		const parsed = Number.parseFloat(input);
		return Number.isFinite(parsed) ? parsed : 0;
	};

	const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));

	const snapVisiblePx = (value: Snap) => {
		const peek = toPx(peekHeight);
		const mid = toPx(initialHeight);
		const full = toPx(expandedHeight);
		if (value === 'collapsed') return peek;
		if (value === 'mid') return mid;
		return full;
	};

	const nearestSnap = (visiblePx: number): Snap => {
		const points: Array<{ key: Snap; px: number }> = [
			{ key: 'collapsed', px: snapVisiblePx('collapsed') },
			{ key: 'mid', px: snapVisiblePx('mid') },
			{ key: 'full', px: snapVisiblePx('full') }
		];
		points.sort((a, b) => Math.abs(a.px - visiblePx) - Math.abs(b.px - visiblePx));
		return points[0].key;
	};

	const visibleHeight = $derived.by(() => {
		if (dragVisiblePx !== null && typeof window !== 'undefined') {
			return `${Math.round(dragVisiblePx)}px`;
		}
		if (snap === 'collapsed') return peekHeight;
		if (snap === 'mid') return initialHeight;
		return expandedHeight;
	});

	const handlePointerDown = (e: PointerEvent) => {
		if (typeof window === 'undefined') return;
		(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
		startY = e.clientY;
		startVisiblePx = snapVisiblePx(snap);
		dragVisiblePx = startVisiblePx;
		isDragging = true;
	};

	const handlePointerMove = (e: PointerEvent) => {
		if (!isDragging) return;
		const delta = startY - e.clientY;
		const next = startVisiblePx + delta;
		dragVisiblePx = clamp(next, snapVisiblePx('collapsed'), snapVisiblePx('full'));
	};

	const handlePointerUp = () => {
		if (!isDragging) return;
		isDragging = false;
		const finalVisible = dragVisiblePx ?? snapVisiblePx(snap);
		snap = nearestSnap(finalVisible);
		isOpen = snap !== 'collapsed';
		dragVisiblePx = null;
	};

	const handleTap = () => {
		const nextSnap: Snap = snap === 'collapsed' ? 'mid' : 'collapsed';
		snap = nextSnap;
		isOpen = nextSnap !== 'collapsed';
	};

	const handleKeydown = (e: KeyboardEvent) => {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			handleTap();
		}
	};

	$effect(() => {
		if (isOpen && snap === 'collapsed') {
			snap = 'mid';
		}
		if (!isOpen && snap !== 'collapsed') {
			snap = 'collapsed';
		}
	});
</script>

<div
	class="bottom-sheet {className}"
	class:open={snap !== 'collapsed'}
	class:dragging={isDragging}
	style:--initial-height={initialHeight}
	style:--expanded-height={expandedHeight}
	style:--peek-height={peekHeight}
	style:--visible-height={visibleHeight}
	role="dialog"
	tabindex="-1"
	aria-label="Panel de información"
	onpointerdown={(event) => event.stopPropagation()}
>
	<div
		class="handle"
		onpointerdown={handlePointerDown}
		onpointermove={handlePointerMove}
		onpointerup={handlePointerUp}
		onpointercancel={handlePointerUp}
		onclick={handleTap}
		onkeydown={handleKeydown}
		role="button"
		tabindex="0"
		aria-label={snap === 'collapsed' ? 'Expandir panel' : 'Contraer panel'}
		aria-expanded={snap !== 'collapsed'}
	></div>

	{#if children}
		<div class="content">
			{@render children()}
		</div>
	{/if}
</div>

<style>
	.bottom-sheet {
		position: absolute;
		bottom: 0;
		left: 0;
		right: 0;
		height: var(--expanded-height, 92vh);
		max-height: var(--expanded-height, 92vh);
		background: linear-gradient(180deg, rgba(252, 248, 238, 0.97), rgba(248, 242, 226, 0.97));
		border-top-left-radius: 1rem;
		border-top-right-radius: 1rem;
		box-shadow: 0 -6px 20px rgba(16, 44, 54, 0.16);
		transform: translateY(calc(100% - var(--visible-height, var(--peek-height, 4.8rem))));
		transition: transform 260ms cubic-bezier(0.4, 0, 0.2, 1);
		z-index: 100;
		overscroll-behavior: contain;
		backdrop-filter: blur(4px);
	}

	.bottom-sheet.dragging {
		transition: none;
	}

	.handle {
		height: 1.6rem;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: grab;
		touch-action: none;
	}

	.handle::before {
		content: '';
		width: 2rem;
		height: 0.3rem;
		background: rgba(16, 44, 54, 0.32);
		border-radius: 999px;
	}

	.handle:active {
		cursor: grabbing;
	}

	.content {
		padding: 0 0.75rem 0.75rem;
		overflow-y: auto;
		max-height: calc(var(--expanded-height, 92vh) - 1.6rem);
	}

	@media (min-width: 901px) {
		.bottom-sheet {
			display: none;
		}
	}
</style>
