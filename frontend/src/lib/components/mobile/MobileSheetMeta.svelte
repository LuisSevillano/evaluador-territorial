<script lang="ts">
	import AppButton from '$lib/components/ui/AppButton.svelte';
	import type { DatasetMetadata, Municipio } from '$lib/types/municipio';

	type Props = {
		datasetMetadata: DatasetMetadata | null;
		shortlistMunicipios: Municipio[];
		onExportCsv: () => void;
		onExportJson: () => void;
	};

	let { datasetMetadata, shortlistMunicipios, onExportCsv, onExportJson }: Props = $props();
</script>

<section class="sheet-meta-panel" aria-label="Metodologia y metadatos">
	<h3>Datos y metodologia</h3>
	{#if datasetMetadata}
		<ul>
			<li><strong>Version:</strong> {datasetMetadata.dataset_version}</li>
			<li><strong>Generado:</strong> {new Date(datasetMetadata.generated_at_utc).toLocaleDateString('es-ES')}</li>
			<li><strong>Periodo clima:</strong> {datasetMetadata.climate_period}</li>
			<li><strong>Fuente clima:</strong> {datasetMetadata.climate_source}</li>
			<li><strong>Alcance:</strong> {datasetMetadata.analysis_scope}</li>
		</ul>
	{:else}
		<p class="sheet-meta">No hay metadatos de dataset disponibles.</p>
	{/if}
	<div class="sheet-export-actions">
		<AppButton label="Exportar shortlist CSV" onclick={onExportCsv} disabled={shortlistMunicipios.length === 0} />
		<AppButton label="Exportar shortlist JSON" onclick={onExportJson} disabled={shortlistMunicipios.length === 0} />
	</div>
</section>

<style>
	.sheet-meta-panel {
		display: grid;
		gap: 0.45rem;
	}
	.sheet-meta-panel h3 {
		margin: 0;
		font-family: 'Fraunces', serif;
		font-size: 1rem;
	}
	.sheet-meta-panel ul {
		margin: 0;
		padding-left: 1rem;
		display: grid;
		gap: 0.2rem;
	}
	.sheet-meta-panel li {
		font-size: 0.76rem;
		color: #3f5753;
	}
	.sheet-export-actions {
		display: flex;
		gap: 0.35rem;
		flex-wrap: wrap;
	}
	:global(.sheet-export-actions .app-btn) {
		font-size: 0.72rem;
	}
</style>
