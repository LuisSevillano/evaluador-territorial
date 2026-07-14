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
	let activeIndex = $state(-1);
	let listboxEl = $state<HTMLUListElement>();

	const suggestionsId = $derived(`${inputId}-suggestions`);
	const optionId = (index: number) => `${suggestionsId}-opt-${index}`;

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
	const activeDescendant = $derived(
		showSearchSuggestions && activeIndex >= 0 ? optionId(activeIndex) : undefined
	);

	const selectSuggestion = (suggestion: SearchSuggestion) => {
		if (suggestion.kind === 'coords') {
			handleSelectCoordinateSuggestion(suggestion.coords);
			return;
		}
		handleSelectMunicipioSuggestion(suggestion.municipio);
	};

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
			activeIndex = -1;
			return;
		}

		const count = searchSuggestions.length;
		if (count === 0) return;

		if (event.key === 'ArrowDown') {
			event.preventDefault();
			activeIndex = activeIndex >= count - 1 ? 0 : activeIndex + 1;
			return;
		}

		if (event.key === 'ArrowUp') {
			event.preventDefault();
			activeIndex = activeIndex <= 0 ? count - 1 : activeIndex - 1;
			return;
		}

		if (event.key === 'Home') {
			event.preventDefault();
			activeIndex = 0;
			return;
		}

		if (event.key === 'End') {
			event.preventDefault();
			activeIndex = count - 1;
			return;
		}

		if (event.key === 'Enter') {
			event.preventDefault();
			selectSuggestion(searchSuggestions[activeIndex >= 0 ? activeIndex : 0]);
		}
	};

	const handleSuggestionPointerDown = (event: PointerEvent, suggestion: SearchSuggestion) => {
		event.preventDefault();
		selectSuggestion(suggestion);
	};

	const handleSuggestionClick = (event: MouseEvent, suggestion: SearchSuggestion) => {
		if (event.detail !== 0) return;
		selectSuggestion(suggestion);
	};

	$effect(() => {
		if (isSearchFocused) return;
		draftQuery = query;
	});

	// Reinicia la opción activa cuando cambian las sugerencias o se cierra el desplegable.
	$effect(() => {
		void searchSuggestions;
		if (!showSearchSuggestions) {
			activeIndex = -1;
		} else if (activeIndex > searchSuggestions.length - 1) {
			activeIndex = -1;
		}
	});

	// Mantiene visible la opción resaltada al navegar con el teclado.
	$effect(() => {
		if (activeIndex < 0 || !listboxEl) return;
		const option = listboxEl.querySelector<HTMLElement>(`#${CSS.escape(optionId(activeIndex))}`);
		option?.scrollIntoView({ block: 'nearest' });
	});
</script>

<div class="search-shell" class:sheet={variant === 'sheet'}>
	<input
		id={inputId}
		name={inputId}
		autocomplete="off"
		type="search"
		role="combobox"
		aria-autocomplete="list"
		aria-expanded={showSearchSuggestions}
		aria-controls={suggestionsId}
		aria-activedescendant={activeDescendant}
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
			<ul class="search-suggestions" id={suggestionsId} role="listbox" bind:this={listboxEl}>
			{#each searchSuggestions as suggestion, index (suggestion.kind === 'coords' ? `coords-${suggestion.coords.label}` : suggestion.municipio.id)}
					<!-- El teclado se gestiona en el input (patrón combobox con aria-activedescendant); la opción no es focalizable. -->
					<!-- svelte-ignore a11y_click_events_have_key_events -->
					<li
						id={optionId(index)}
						role="option"
						aria-selected={activeIndex === index}
						class="suggestion-btn"
						class:active={activeIndex === index}
						onpointerdown={(event) => handleSuggestionPointerDown(event, suggestion)}
						onclick={(event) => handleSuggestionClick(event, suggestion)}
						onpointermove={() => (activeIndex = index)}
					>
						{#if suggestion.kind === 'coords'}
							<span>{suggestion.coords.label}</span>
						{:else}
							<span>{suggestion.municipio.nombre}</span>
							<small>{suggestion.municipio.provincia}</small>
						{/if}
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
		border: 1px solid var(--control-border);
		border-radius: var(--radius-card);
		background: var(--control-bg);
		font-size: 0.82rem;
		color: var(--text-primary);
	}

	.search-shell.sheet {
		margin-top: 0;
	}

	.search-shell.sheet input[type='search'] {
		margin-top: 0;
		height: 30px;
		padding: 0 0.5rem;
		border-radius: var(--radius-card);
		font-size: 0.8rem;
		line-height: 1.2;
		background: var(--control-bg);
	}

	.search-dropdown {
		position: absolute;
		top: calc(100% + 4px);
		left: 0;
		right: 0;
		background: color-mix(in srgb, var(--surface) 96%, transparent);
		border: 1px solid var(--control-border);
		border-radius: var(--radius-panel);
		box-shadow: var(--shadow-soft);
		backdrop-filter: blur(8px);
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

	.suggestion-btn:hover,
	.suggestion-btn.active {
		background: var(--active-bg);
		transform: translateX(1px);
	}

	.suggestion-btn:focus-visible {
		outline: 2px solid var(--focus-ring);
		outline-offset: 2px;
	}

	small {
		color: var(--text-muted);
		font-size: 0.72rem;
	}
</style>
