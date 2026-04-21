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

	let startY = 0;
	let currentY = 0;
	let isDragging = $state(false);

	const handlePointerDown = (e: PointerEvent) => {
		startY = e.clientY;
		isDragging = true;
	};

	const handlePointerMove = (e: PointerEvent) => {
		if (!isDragging) return;
		currentY = startY - e.clientY;
	};

	const handlePointerUp = (e: PointerEvent) => {
		if (!isDragging) return;
		isDragging = false;

		const delta = startY - e.clientY;
		if (delta > 80) isOpen = false;
		else if (delta < -40) isOpen = true;
		currentY = 0;
	};

	const handleTap = () => {
		isOpen = !isOpen;
	};

	const handleKeydown = (e: KeyboardEvent) => {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			isOpen = !isOpen;
		}
	};
</script>

<div
	class="bottom-sheet {className}"
	class:open={isOpen}
	style:--initial-height={initialHeight}
	style:--expanded-height={expandedHeight}
	style:--peek-height={peekHeight}
	role="dialog"
	aria-label="Panel de información"
>
	<div
		class="handle"
		onpointerdown={handlePointerDown}
		onpointermove={handlePointerMove}
		onpointerup={handlePointerUp}
		onclick={handleTap}
		onkeydown={handleKeydown}
		role="button"
		tabindex="0"
		aria-label={isOpen ? 'Contraer panel' : 'Expandir panel'}
		aria-expanded={isOpen}
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
		height: var(--initial-height, 35vh);
		max-height: var(--initial-height, 35vh);
		background: linear-gradient(180deg, rgba(252, 248, 238, 0.97), rgba(248, 242, 226, 0.97));
		border-top-left-radius: 1rem;
		border-top-right-radius: 1rem;
		box-shadow: 0 -6px 20px rgba(16, 44, 54, 0.16);
		transform: translateY(calc(100% - var(--peek-height, 4.8rem)));
		transition: transform 260ms cubic-bezier(0.4, 0, 0.2, 1);
		z-index: 100;
		overscroll-behavior: contain;
		backdrop-filter: blur(4px);
	}

	.bottom-sheet.open {
		transform: translateY(0);
		height: var(--expanded-height, 92vh);
		max-height: var(--expanded-height, 92vh);
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
