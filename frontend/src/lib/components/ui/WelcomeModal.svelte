<script lang="ts">
	type Props = {
		isOpen?: boolean;
		dontShowAgain?: boolean;
		onClose?: () => void;
	};

	let { isOpen = $bindable(false), dontShowAgain = $bindable(false), onClose }: Props = $props();

	const close = () => {
		onClose?.();
	};

	const handleOverlayClick = (event: MouseEvent) => {
		if (event.currentTarget === event.target) {
			close();
		}
	};

	$effect(() => {
		if (typeof window === 'undefined' || !isOpen) return;

		const handleKeydown = (event: KeyboardEvent) => {
			if (event.key === 'Escape') {
				event.preventDefault();
				close();
			}
		};

		window.addEventListener('keydown', handleKeydown);
		return () => window.removeEventListener('keydown', handleKeydown);
	});
</script>

{#if isOpen}
	<div class="welcome-overlay" role="presentation" onclick={handleOverlayClick}>
		<div class="welcome-modal" role="dialog" aria-modal="true" aria-labelledby="welcome-title">
			<button type="button" class="welcome-close" onclick={close} aria-label="Cerrar introduccion">
				×
			</button>

			<p class="welcome-kicker">Bienvenida al atlas territorial de El Buen Vivir</p>
			<h2 id="welcome-title">Explora municipios con criterios comparables</h2>
			<p>
				Esta herramienta reúne datos territoriales para comparar municipios de forma visual:
				<span class="topic-badge climate">clima</span>,
				<span class="topic-badge access">accesibilidad</span>,
				<span class="topic-badge nature">naturaleza</span>, agua, relieve y otros indicadores se
				combinan en una puntuación mixta que puedes adaptar a tus prioridades.
			</p>
			<p>
				El objetivo no es decir cuál es el mejor municipio en términos absolutos, sino ayudarte a
				explorar patrones, descartar zonas y construir una selección razonada dentro del alcance
				analizado.
			</p>
			<ul>
				<li>Usa filtros para acotar por provincia, clima y accesibilidad.</li>
				<li>
					Ajusta pesos para priorizar lo que más te importa: clima, naturaleza o distancia desde
					Madrid.
				</li>
				<li>Explora el mapa y el ranking para comparar rapidamente.</li>
			</ul>

			<div class="welcome-actions">
				<button type="button" class="welcome-start" onclick={close}>Empezar a explorar</button>
				<a class="welcome-docs" href="/docs/">Ver documentacion</a>
			</div>

			<label class="welcome-checkbox">
				<input type="checkbox" bind:checked={dontShowAgain} />
				<span>No volver a mostrar</span>
			</label>
		</div>
	</div>
{/if}

<style>
	.welcome-overlay {
		position: fixed;
		inset: 0;
		display: grid;
		place-items: center;
		padding: 1rem;
		background: rgba(20, 30, 31, 0.46);
		backdrop-filter: blur(2px);
		z-index: 1300;
	}

	.welcome-modal {
		position: relative;
		width: min(680px, 100%);
		max-height: min(88dvh, 760px);
		overflow: auto;
		padding: 1.3rem 1.2rem 1rem;
		border: 1px solid rgba(16, 44, 54, 0.24);
		border-radius: 16px;
		background: linear-gradient(180deg, rgba(255, 251, 243, 0.99), rgba(248, 242, 227, 0.99));
		box-shadow: 0 24px 54px rgba(12, 30, 38, 0.35);
	}

	.welcome-close {
		position: absolute;
		top: 0.55rem;
		right: 0.55rem;
		display: flex;
		align-items: center;
		justify-content: center;
		border: 0;
		width: 2rem;
		height: 2rem;
		padding: 0;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.9);
		color: #244742;
		font-size: 1.35rem;
		line-height: 1;
		cursor: pointer;
		border: 1px solid rgba(21, 32, 33, 0.24);
	}

	.welcome-kicker {
		margin: 0;
		font-size: 0.72rem;
		letter-spacing: 0.1em;
		text-transform: uppercase;
		color: #4b6460;
	}

	h2 {
		margin: 0.25rem 0 0.65rem;
		font-family: 'Fraunces', serif;
		font-size: clamp(1.25rem, 1.85vw, 1.62rem);
		line-height: 1.2;
		color: #173f39;
	}

	p {
		margin: 0;
		font-size: 0.95rem;
		line-height: 1.45;
		color: #314d49;
	}

	p + p {
		margin-top: 0.7rem;
	}

	ul {
		margin: 0.85rem 0 0;
		padding-left: 1.1rem;
		display: grid;
		gap: 0.36rem;
		color: #314d49;
		font-size: 0.9rem;
	}

	.welcome-actions {
		margin-top: 1rem;
		display: flex;
		gap: 0.5rem;
		flex-wrap: wrap;
	}

	.welcome-docs,
	.welcome-start {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		padding: 0.45rem 0.7rem;
		border-radius: 999px;
		font-size: 0.8rem;
		font-weight: 600;
		text-decoration: none;
	}

	.welcome-docs {
		border: 1px solid rgba(21, 32, 33, 0.24);
		background: rgba(255, 255, 255, 0.9);
		color: #244742;
	}

	.welcome-start {
		border: 1px solid rgba(26, 79, 85, 0.4);
		background: rgba(47, 125, 133, 0.16);
		color: #1d5f66;
		cursor: pointer;
	}

	.welcome-checkbox {
		margin-top: 0.8rem;
		display: inline-flex;
		align-items: center;
		gap: 0.45rem;
		font-size: 0.82rem;
		color: #3e5955;
	}

	.topic-badge {
		display: inline-flex;
		align-items: center;
		padding: 0.08rem 0.38rem 0.1rem;
		border-radius: 999px;
		border: 1px solid transparent;
		font-size: 0.78rem;
		font-weight: 700;
		line-height: 1.15;
		white-space: nowrap;
		color: white;
	}

	.topic-badge.climate {
		border-color: #2b6cb0;
		background: color-mix(in srgb, #2b6cb0 16%, white);
		color: #2b6cb0;
	}

	.topic-badge.nature {
		border-color: #2f855a;
		background: color-mix(in srgb, #2f855a 16%, white);
		color: #2f855a;
	}

	.topic-badge.access {
		border-color: #805ad5;
		background: color-mix(in srgb, #805ad5 16%, white);
		color: #805ad5;
	}

	@media (max-width: 900px) {
		.welcome-overlay {
			padding: 0.7rem;
		}

		.welcome-modal {
			max-height: 90dvh;
			padding: 1.65rem 0.9rem 0.9rem;
		}

		.welcome-kicker {
			padding-right: 2.2rem;
		}
	}
</style>
