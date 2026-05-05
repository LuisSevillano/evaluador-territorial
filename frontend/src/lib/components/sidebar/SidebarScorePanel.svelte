<script lang="ts">
	import ScoreControls from '$lib/components/scoring/ScoreControls.svelte';

	type Preset = 'equilibrado' | 'naturaleza' | 'accesibilidad' | 'clima' | 'clima_estricto';
	type Props = {
		weights: { climate: number; access: number; nature: number };
		weightsRaw: { climateWeight: number; accessWeight: number; natureWeight: number };
		sensitivityOverlap: number;
		activePreset: Preset | null;
		onPresetWeights: (preset: Preset) => void;
		onClimateWeightChange: (value: number) => void;
		onAccessWeightChange: (value: number) => void;
		onNatureWeightChange: (value: number) => void;
	};

	let {
		weights,
		weightsRaw,
		sensitivityOverlap,
		activePreset,
		onPresetWeights,
		onClimateWeightChange,
		onAccessWeightChange,
		onNatureWeightChange
	}: Props = $props();
</script>

<ScoreControls
	{weights}
	{weightsRaw}
	{sensitivityOverlap}
	{activePreset}
	{onPresetWeights}
	{onClimateWeightChange}
	{onAccessWeightChange}
	{onNatureWeightChange}
	idPrefix="m"
	subtitle="Estos pesos cambian el score y el ranking; el filtro de score minimo decide que municipios se muestran en mapa y tabla."
 />
