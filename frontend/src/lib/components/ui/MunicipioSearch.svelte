<script lang="ts">
	import type { Municipio } from '$lib/types/municipio';
	import { parseCoordinateQuery, type CoordinateMatch } from '$lib/utils/coordinateSearch';

	type Props = {
		query?: string;
		municipios?: Municipio[];
		searchMunicipios?: Municipio[];
		inputId?: string;
		placeholder?: string;
		variant?: 'default' | 'sheet';
		onQueryChange?: (value: string) => void;
		onSelectMunicipio?: (municipio: Municipio) => void;
		onCoordinateSearch?: (payload: { lat: number; lon: number; label: string }) => void;
	};

	let {
		query = '',
		municipios = [],
		searchMunicipios = [],
		inputId = 'municipio-search',
		placeholder = 'Ej. Soria o 41.68, -3.69',
		variant = 'default',
		onQueryChange = () => undefined,
		onSelectMunicipio = () => undefined,
		onCoordinateSearch = () => undefined
	}: Props = $props();

	let isSearchFocused = $state(false);
	let draftQuery = $state('');
	let selectedDuringFocus = $state(false);

	const suggestionsId = $derived(`${inputId}-suggestions`);

	type SearchSuggestion =
		| { kind: 'municipio'; municipio: Municipio; starts: boolean }
		| { kind: 'coords'; coords: CoordinateMatch };

	const searchSuggestions = $derived.by((): SearchSuggestion[] => {
		const source = searchMunicipios.length > 0 ? searchMunicipios : municipios;
		const normalized = draftQuery.trim().toLowerCase();
		const coords = parseCoordinateQuery(draftQuery);

		if (coords) {
			return [{ kind: 'coords', coords }];
		}

		if (!normalized) {
			return [...source]
				.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
				.slice(0, 10)
				.map((municipio) => ({ kind: 'municipio', municipio, starts: true }));
		}

		return source
			.map((municipio) => {
				const nombre = municipio.nombre.toLowerCase();
				const haystack = `${municipio.nombre} ${municipio.provincia}`.toLowerCase();
				const starts = nombre.startsWith(normalized);
				const includes = haystack.includes(normalized);
				if (!includes) return null;
				return { municipio, starts };
			})
			.filter((item): item is { municipio: Municipio; starts: boolean } => item !== null)
			.sort((a, b) => {
				if (a.starts !== b.starts) return a.starts ? -1 : 1;
				return a.municipio.nombre.localeCompare(b.municipio.nombre, 'es');
			})
			.map(
				(item): SearchSuggestion => ({
					kind: 'municipio',
					municipio: item.municipio,
					starts: item.starts
				})
			)
			.slice(0, 10);
	});

	const showSearchSuggestions = $derived(isSearchFocused && searchSuggestions.length > 0);

	const handleSearchBlur = () => {
		setTimeout(() => {
			if (!selectedDuringFocus) {
				onQueryChange('');
				draftQuery = '';
			}
			selectedDuringFocus = false;
			isSearchFocused = false;
		}, 90);
	};

	const handleSelectMunicipioSuggestion = (municipio: Municipio) => {
		selectedDuringFocus = true;
		onSelectMunicipio(municipio);
		onQueryChange(municipio.nombre);
		draftQuery = municipio.nombre;
		isSearchFocused = false;
	};

	const handleSelectCoordinateSuggestion = (coords: CoordinateMatch) => {
		selectedDuringFocus = true;
		onCoordinateSearch(coords);
		onQueryChange(coords.label);
		draftQuery = coords.label;
		isSearchFocused = false;
	};

	const handleSearchKeydown = (event: KeyboardEvent) => {
		if (event.key === 'Escape') {
			onQueryChange('');
			draftQuery = '';
			selectedDuringFocus = false;
			isSearchFocused = false;
			return;
		}

		if (event.key === 'Enter' && searchSuggestions.length > 0) {
			event.preventDefault();
			const first = searchSuggestions[0];
			if (first.kind === 'coords') {
				handleSelectCoordinateSuggestion(first.coords);
				return;
			}
			handleSelectMunicipioSuggestion(first.municipio);
		}
	};

	const handleSuggestionPointerDown = (event: PointerEvent, suggestion: SearchSuggestion) => {
		event.preventDefault();
		if (suggestion.kind === 'coords') {
			handleSelectCoordinateSuggestion(suggestion.coords);
			return;
		}
		handleSelectMunicipioSuggestion(suggestion.municipio);
	};

	const handleSuggestionClick = (event: MouseEvent, suggestion: SearchSuggestion) => {
		if (event.detail !== 0) return;
		if (suggestion.kind === 'coords') {
			handleSelectCoordinateSuggestion(suggestion.coords);
			return;
		}
		handleSelectMunicipioSuggestion(suggestion.municipio);
	};

	$effect(() => {
		if (isSearchFocused) return;
		draftQuery = query;
	});
</script>

<div
	class="search-shell"
	class:sheet={variant === 'sheet'}
	role="combobox"
	aria-expanded={showSearchSuggestions}
	aria-controls={suggestionsId}
>
	<input
		id={inputId}
		name={inputId}
		autocomplete="off"
		type="search"
		{placeholder}
		value={draftQuery}
		onfocus={() => {
			isSearchFocused = true;
			selectedDuringFocus = false;
		}}
		onblur={handleSearchBlur}
		onkeydown={handleSearchKeydown}
		oninput={(e) => {
			draftQuery = (e.currentTarget as HTMLInputElement).value;
			if (draftQuery.trim().length === 0) onQueryChange('');
		}}
	/>
	{#if showSearchSuggestions}
		<div class="search-dropdown">
			<ul class="search-suggestions" id={suggestionsId} role="listbox">
			{#each searchSuggestions as suggestion (suggestion.kind === 'coords' ? `coords-${suggestion.coords.label}` : suggestion.municipio.id)}
					<li>
						<button
							class="suggestion-btn"
							onpointerdown={(event) => handleSuggestionPointerDown(event, suggestion)}
							onclick={(event) => handleSuggestionClick(event, suggestion)}
						>
							{#if suggestion.kind === 'coords'}
								<span>{suggestion.coords.label}</span>
							{:else}
								<span>{suggestion.municipio.nombre}</span>
								<small>{suggestion.municipio.provincia}</small>
							{/if}
						</button>
					</li>
				{/each}
			</ul>
		</div>
	{/if}
</div>

<style>
	.search-shell {
		position: relative;
		margin-top: 0.1rem;
	}

	input[type='search'] {
		width: 100%;
		margin-top: 0.35rem;
		padding: 0.62rem 0.7rem;
		border: 1px solid rgba(21, 32, 33, 0.2);
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.78);
		font-size: 0.82rem;
		color: #304643;
	}

	.search-shell.sheet {
		margin-top: 0;
	}

	.search-shell.sheet input[type='search'] {
		margin-top: 0;
		height: 30px;
		padding: 0 0.5rem;
		border-radius: 8px;
		font-size: 0.8rem;
		line-height: 1.2;
		background: rgba(255, 255, 255, 0.86);
	}

	.search-dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		background: rgba(255, 252, 246, 0.98);
		border: 1px solid rgba(21, 32, 33, 0.24);
		border-radius: 12px;
		box-shadow: 0 12px 24px rgba(21, 32, 33, 0.16);
		backdrop-filter: blur(2px);
		overflow: hidden;
		z-index: 30;
	}

	.search-suggestions {
		list-style: none;
		padding: 0.24rem;
		margin: 0;
		display: grid;
		gap: 0.2rem;
		max-height: 248px;
		overflow-y: auto;
	}

	.suggestion-btn {
		width: 100%;
		text-align: left;
		border: 0;
		border-radius: 8px;
		background: transparent;
		padding: 0.42rem 0.5rem;
		display: grid;
		cursor: pointer;
		transition: background-color 140ms ease, transform 140ms ease;
		font-size: 0.8rem;
		line-height: 1.2;
	}

	.suggestion-btn:hover {
		background: rgba(47, 125, 133, 0.12);
		transform: translateX(1px);
	}

	.suggestion-btn:focus-visible {
		outline: 2px solid #2f7d85;
		outline-offset: 2px;
	}

	small {
		color: #48615d;
		font-size: 0.72rem;
	}
</style>
