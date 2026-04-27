<script lang="ts">
	import type { Municipio } from '$lib/types/municipio';

	type Props = {
		query?: string;
		municipios?: Municipio[];
		searchMunicipios?: Municipio[];
		inputId?: string;
		placeholder?: string;
		variant?: 'default' | 'sheet';
		onQueryChange?: (value: string) => void;
		onSelectMunicipio?: (municipio: Municipio) => void;
	};

	let {
		query = '',
		municipios = [],
		searchMunicipios = [],
		inputId = 'municipio-search',
		placeholder = 'Ej. Soria…',
		variant = 'default',
		onQueryChange = () => undefined,
		onSelectMunicipio = () => undefined
	}: Props = $props();

	let isSearchFocused = $state(false);
	let draftQuery = $state('');
	let selectedDuringFocus = $state(false);

	const suggestionsId = $derived(`${inputId}-suggestions`);

	const searchSuggestions = $derived.by(() => {
		const source = searchMunicipios.length > 0 ? searchMunicipios : municipios;
		const normalized = draftQuery.trim().toLowerCase();

		if (!normalized) {
			return [...source]
				.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))
				.slice(0, 10);
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
			.map((item) => item.municipio)
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

	const handleSelectSuggestion = (municipio: Municipio) => {
		selectedDuringFocus = true;
		onSelectMunicipio(municipio);
		onQueryChange(municipio.nombre);
		draftQuery = municipio.nombre;
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
			handleSelectSuggestion(searchSuggestions[0]);
		}
	};

	const handleSuggestionPointerDown = (event: PointerEvent, municipio: Municipio) => {
		event.preventDefault();
		handleSelectSuggestion(municipio);
	};

	const handleSuggestionClick = (event: MouseEvent, municipio: Municipio) => {
		if (event.detail === 0) handleSelectSuggestion(municipio);
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
				{#each searchSuggestions as municipio (municipio.id)}
					<li>
						<button
							class="suggestion-btn"
							onpointerdown={(event) => handleSuggestionPointerDown(event, municipio)}
							onclick={(event) => handleSuggestionClick(event, municipio)}
						>
							<span>{municipio.nombre}</span>
							<small>{municipio.provincia}</small>
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
