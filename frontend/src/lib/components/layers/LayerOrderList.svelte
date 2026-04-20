<script lang="ts">
	type LayerItem = {
		key: string;
		label: string;
		visible: boolean;
	};

	type Props = {
		items?: LayerItem[];
		onToggle?: (layerKey: string, checked: boolean) => void;
		onReorder?: (nextOrder: string[]) => void;
	};

	let { items = [], onToggle = () => undefined, onReorder = () => undefined }: Props = $props();

	let draggingLayer = $state<string | null>(null);

	const onDragStartLayer = (event: DragEvent, layerKey: string) => {
		draggingLayer = layerKey;
		event.dataTransfer?.setData('text/plain', layerKey);
		event.dataTransfer?.setDragImage(event.currentTarget as Element, 16, 12);
	};

	const onDropLayer = (event: DragEvent, targetKey: string) => {
		event.preventDefault();
		const sourceKey = event.dataTransfer?.getData('text/plain') || draggingLayer;
		if (!sourceKey || sourceKey === targetKey) return;

		const nextOrder = items.map((item) => item.key);
		const sourceIndex = nextOrder.indexOf(sourceKey);
		const targetIndex = nextOrder.indexOf(targetKey);
		if (sourceIndex < 0 || targetIndex < 0) return;

		nextOrder.splice(sourceIndex, 1);
		nextOrder.splice(targetIndex, 0, sourceKey);
		onReorder(nextOrder);
		draggingLayer = null;
	};
</script>

<ul class="layer-order">
	{#each items as item (item.key)}
		<li
			draggable="true"
			ondragstart={(event) => onDragStartLayer(event, item.key)}
			ondragover={(event) => event.preventDefault()}
			ondrop={(event) => onDropLayer(event, item.key)}
		>
			<label>
				<input
					type="checkbox"
					checked={item.visible}
					onchange={(event) => onToggle(item.key, (event.currentTarget as HTMLInputElement).checked)}
				/>
				<span>{item.label}</span>
			</label>
			<small>::</small>
		</li>
	{/each}
</ul>

<style>
	.layer-order { margin-top: 0.2rem; margin-bottom: 0; padding-left: 0; list-style: none; }
	.layer-order li { border: 1px dashed rgba(21, 32, 33, 0.28); border-radius: 8px; padding: 0.3rem 0.5rem; background: rgba(255, 255, 255, 0.72); cursor: grab; display: flex; align-items: center; justify-content: space-between; gap: 0.5rem; }
	.layer-order li:active { cursor: grabbing; }
	.layer-order li label { display: inline-flex; align-items: center; gap: 0.45rem; font-size: 0.78rem; color: #2f4542; margin: 0; }
	.layer-order li small { color: #5a6f6b; font-size: 0.74rem; letter-spacing: 0.08em; }
	@media (max-width: 900px) {
		.layer-order li label { font-size: 0.8rem; }
		.layer-order li small { font-size: 0.76rem; }
	}
</style>
