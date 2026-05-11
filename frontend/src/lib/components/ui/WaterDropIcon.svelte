<script lang="ts">
	type Props = {
		count?: number;
		size?: number;
		color?: string;
	};
	let { count = 1, size = 14, color = 'currentColor' }: Props = $props();
</script>

<div>
	{#each Array(count) as _, i}
		<svg
			width={size}
			height={size * 1.25}
			viewBox="0 0 12 14"
			fill="none"
			xmlns="http://www.w3.org/2000/svg"
			style="display:inline-block;flex-shrink:0"
			aria-hidden="true"
		>
			<path
				d="M6 1C6 1 2 5.5 2 8.5C2 11.04 3.79 13 6 13C8.21 13 10 11.04 10 8.5C10 5.5 6 1 6 1Z"
				fill={color}
				opacity={0.85 - i * 0.05}
			/>
		</svg>
	{/each}
</div>

<style>
	div {
		margin-right: 2px;
		display: flex;
	}
</style>
