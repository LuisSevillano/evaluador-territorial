<script lang="ts">
	import { tick } from 'svelte';

	type Props = {
		text: string;
	};

	let { text }: Props = $props();

	let open = $state(false);
	let placeAbove = $state(true);
	let align = $state<'center' | 'left' | 'right'>('center');

	let triggerEl = $state<HTMLButtonElement | null>(null);
	let popupEl = $state<HTMLSpanElement | null>(null);

	const viewportMargin = 8;

	const updatePosition = () => {
		if (!triggerEl || typeof window === 'undefined') return;
		const triggerRect = triggerEl.getBoundingClientRect();
		const popupWidth = popupEl?.offsetWidth ?? 240;
		const popupHeight = popupEl?.offsetHeight ?? 72;
		const preferAbove = window.innerWidth <= 900;

		const idealLeft = triggerRect.left + triggerRect.width / 2 - popupWidth / 2;
		if (idealLeft < viewportMargin) align = 'left';
		else if (idealLeft + popupWidth > window.innerWidth - viewportMargin) align = 'right';
		else align = 'center';

		const aboveTop = triggerRect.top - popupHeight - 8;
		const belowTop = triggerRect.bottom + 8;
		const canPlaceAbove = aboveTop >= viewportMargin;
		const canPlaceBelow = belowTop + popupHeight + viewportMargin <= window.innerHeight;

		if (preferAbove) {
			placeAbove = canPlaceAbove || !canPlaceBelow;
		} else {
			placeAbove = !canPlaceBelow && canPlaceAbove;
		}

	};

	const openTooltip = async () => {
		open = true;
		await tick();
		updatePosition();
	};

	const closeTooltip = () => {
		open = false;
	};

	const toggleTooltip = async (event: Event) => {
		event.preventDefault();
		event.stopPropagation();
		if (open) {
			closeTooltip();
			return;
		}
		await openTooltip();
	};

	$effect(() => {
		if (!open || typeof window === 'undefined') return;
		const syncPosition = () => updatePosition();
		const closeOnOutside = (event: MouseEvent | TouchEvent) => {
			const target = event.target as Node | null;
			if (!target) return;
			if (triggerEl?.contains(target) || popupEl?.contains(target)) return;
			closeTooltip();
		};
		const closeOnEsc = (event: KeyboardEvent) => {
			if (event.key === 'Escape') closeTooltip();
		};
		window.addEventListener('resize', syncPosition);
		window.addEventListener('scroll', syncPosition, true);
		window.addEventListener('mousedown', closeOnOutside);
		window.addEventListener('touchstart', closeOnOutside, { passive: true });
		window.addEventListener('keydown', closeOnEsc);
		return () => {
			window.removeEventListener('resize', syncPosition);
			window.removeEventListener('scroll', syncPosition, true);
			window.removeEventListener('mousedown', closeOnOutside);
			window.removeEventListener('touchstart', closeOnOutside);
			window.removeEventListener('keydown', closeOnEsc);
		};
	});
</script>

<span class="help-wrap">
	<button
		type="button"
		class="help-trigger"
		aria-label="Ayuda del filtro"
		aria-expanded={open}
		bind:this={triggerEl}
		onclick={toggleTooltip}
		onfocus={openTooltip}
		onblur={closeTooltip}
	>
		<svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true" focusable="false">
			<path d="M8 15A7 7 0 1 1 8 1a7 7 0 0 1 0 14m0 1A8 8 0 1 0 8 0a8 8 0 0 0 0 16" />
			<path d="m8.93 6.588-2.29.287-.082.38.45.083c.294.07.352.176.288.469l-.738 3.468c-.194.897.105 1.319.808 1.319.545 0 1.178-.252 1.465-.598l.088-.416c-.2.176-.492.246-.686.246-.275 0-.375-.193-.304-.533zM9 4.5a1 1 0 1 1-2 0 1 1 0 0 1 2 0" />
		</svg>
	</button>
	{#if open}
		<span
			class="help-popup"
			class:above={placeAbove}
			class:align-left={align === 'left'}
			class:align-right={align === 'right'}
			role="tooltip"
			bind:this={popupEl}
		>
			{text}
		</span>
	{/if}
</span>

<style>
	.help-wrap {
		position: relative;
		display: inline-flex;
		align-items: center;
	}

	.help-trigger {
		width: 15px;
		height: 15px;
		border: 0;
		border-radius: 999px;
		background: transparent;
		color: #395955;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		cursor: help;
		opacity: 0.88;
		transition: opacity 120ms ease, transform 120ms ease;
	}

	.help-trigger:hover {
		opacity: 1;
		transform: translateY(-0.5px);
	}

	.help-trigger :global(svg) {
		display: block;
	}

	.help-popup {
		position: absolute;
		left: 50%;
		bottom: calc(100% + 8px);
		transform: translateX(-50%);
		min-width: 170px;
		max-width: min(240px, calc(100vw - 16px));
		padding: 0.4rem 0.5rem;
		border-radius: 8px;
		border: 1px solid rgba(24, 37, 38, 0.28);
		background: rgba(255, 253, 248, 0.98);
		box-shadow: 0 8px 20px rgba(15, 28, 28, 0.18);
		font-size: 11px;
		font-weight: 400;
		line-height: 1.25;
		letter-spacing: normal;
		text-transform: none;
		color: #2e4743;
		pointer-events: none;
		z-index: 90;
		overflow-wrap: anywhere;
	}

	.help-popup:not(.above) {
		bottom: auto;
		top: calc(100% + 8px);
	}

	.help-popup.align-left {
		left: 0;
		transform: none;
	}

	.help-popup.align-right {
		left: auto;
		right: 0;
		transform: none;
	}

	.help-trigger:focus-visible {
		outline: 2px solid #2f7d85;
		outline-offset: 1px;
	}
</style>
