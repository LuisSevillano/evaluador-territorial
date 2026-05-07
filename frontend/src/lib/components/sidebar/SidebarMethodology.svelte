<script lang="ts">
	import type { DatasetMetadata } from '$lib/types/municipio';
	import { formatScorePercent } from '$lib/utils/numberFormat';

	type Props = {
		datasetMetadata?: DatasetMetadata | null;
		scoringActiveText?: string;
	};

	let {
		datasetMetadata = null,
		scoringActiveText = ''
	}: Props = $props();
</script>

<section class="panel methodology">
	<details>
		<summary>Metodologia y trazabilidad</summary>
		<div class="method-body">
			{#if datasetMetadata}
				<p><strong>Fuente climatica:</strong> {datasetMetadata.climate_source}</p>
				<p><strong>Periodo:</strong> {datasetMetadata.climate_period}</p>
				<p><strong>Agregacion municipal:</strong> {datasetMetadata.aggregation_method}</p>
				<p><strong>Isocronas:</strong> {datasetMetadata.isochrones_definition}</p>
				<p><strong>Fecha de generacion:</strong> {datasetMetadata.generated_at_utc}</p>
				<p><strong>Version dataset:</strong> {datasetMetadata.dataset_version}</p>
				<p><strong>Scoring base dataset:</strong> {datasetMetadata.scoring_method ?? 'No definido'}</p>
				<p><strong>Scoring activo:</strong> {scoringActiveText}</p>
				{#if typeof datasetMetadata.accessibility_normalization_floor === 'number'}
					<p><strong>Suelo accesibilidad:</strong> {formatScorePercent(datasetMetadata.accessibility_normalization_floor)}%</p>
				{/if}
			{:else}
				<p class="muted">Sin metadata disponible en este build.</p>
			{/if}
		</div>
	</details>
</section>

<style>
	section.panel {
		border: 1px solid rgba(21, 32, 33, 0.16);
		border-radius: 12px;
		padding: 0.8rem;
		background: rgba(255, 255, 255, 0.62);
	}
	p {
		margin: 0;
	}
	.methodology details {
		border: 1px dashed rgba(21, 32, 33, 0.22);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.5);
	}
	.methodology summary {
		cursor: pointer;
		padding: 0.55rem 0.65rem;
		font-family: 'Fraunces', serif;
		font-size: 0.86rem;
		margin: 0;
	}
	.method-body {
		display: grid;
		gap: 0.35rem;
		padding: 0 0.65rem 0.65rem;
		font-size: 0.78rem;
	}
	.method-body p {
		margin: 0;
	}
	.muted {
		color: #48615d;
		font-size: 0.76rem;
		line-height: 1.35;
	}
</style>
