export default {
	title: 'Observatorio Territorial',
	description: 'Documentación práctica del Atlas / Evaluador Territorial de El Buen Vivir',
	lang: 'es-ES',
	site: 'https://observatorio-territorial.netlify.app/docs/',
	base: '/docs/',
	appearance: 'dark',
	head: [
		['link', { rel: 'icon', type: 'image/svg+xml', href: '/docs/favicon-docs.svg' }],
		['meta', { property: 'og:type', content: 'website' }],
		['meta', { property: 'og:url', content: 'https://observatorio-territorial.netlify.app/docs/' }],
		['meta', { property: 'og:title', content: 'Documentación | Observatorio Territorial' }],
		[
			'meta',
			{
				property: 'og:description',
				content:
					'Guía técnica y metodológica del Evaluador Territorial: pipeline, indicadores, criterios de análisis y operación del Atlas.'
			}
		],
		['meta', { property: 'og:site_name', content: 'Observatorio Territorial Docs' }],
		['meta', { property: 'og:locale', content: 'es_ES' }],
		['meta', { property: 'og:image', content: 'https://observatorio-territorial.netlify.app/docs/og-docs.png' }],
		['meta', { property: 'og:image:secure_url', content: 'https://observatorio-territorial.netlify.app/docs/og-docs.png' }],
		['meta', { property: 'og:image:type', content: 'image/png' }],
		['meta', { property: 'og:image:width', content: '1200' }],
		['meta', { property: 'og:image:height', content: '630' }],
		['meta', { property: 'og:image:alt', content: 'Documentación del Observatorio Territorial' }],
		['meta', { property: 'twitter:card', content: 'summary_large_image' }],
		['meta', { property: 'twitter:title', content: 'Documentación | Observatorio Territorial' }],
		[
			'meta',
			{
				property: 'twitter:description',
				content:
					'Guía técnica y metodológica del Evaluador Territorial: pipeline, indicadores, criterios de análisis y operación del Atlas.'
			}
		],
		['meta', { property: 'twitter:image', content: 'https://observatorio-territorial.netlify.app/docs/og-docs.png' }],
		['meta', { name: 'twitter:image:src', content: 'https://observatorio-territorial.netlify.app/docs/og-docs.png' }]
	],
	themeConfig: {
		nav: [{ text: 'Atlas', link: 'https://observatorio-territorial.netlify.app/' }],
		sidebar: [
			{
				text: 'Entender el Atlas',
				items: [
					{ text: 'Qué es este Atlas', link: '/' },
					{ text: 'Arquitectura del Atlas', link: '/arquitectura' },
					{ text: 'Cómo leer resultados con criterio', link: '/analisis-objetividad' },
					{ text: 'Cómo se comparan los lugares', link: '/metodologia' }
				]
			},
			{
				text: 'Cómo usar el Atlas',
				items: [
					{ text: 'Visión general de uso', link: '/uso-atlas/' },
					{ text: 'Guía de Escritorio', link: '/uso-atlas/desktop' },
					{ text: 'Guía de Móvil', link: '/uso-atlas/mobile' },
					{ text: 'Comportamientos esperados', link: '/uso-atlas/comportamientos' }
				]
			},
			{
				text: 'Pipeline de datos',
				items: [
					{ text: 'Visión general del pipeline', link: '/pipeline/' },
					{ text: 'Trazabilidad', link: '/pipeline/trazabilidad' },
					{ text: 'Fuentes de datos', link: '/pipeline/fuentes' },
					{ text: 'Scripts detallados', link: '/pipeline/scripts-detalle' }
				]
			},
			{
				text: 'Indicadores',
				items: [
					{ text: 'Qué se analiza', link: '/indicadores/' },
					{ text: 'Diccionario completo', link: '/indicadores/data-dictionary' },
					{ text: 'Clima', link: '/indicadores/clima' },
					{ text: 'Accesibilidad', link: '/indicadores/accesibilidad' },
					{ text: 'Naturaleza y ríos', link: '/indicadores/naturaleza-rios' },
					{ text: 'Score compuesto', link: '/indicadores/score' }
				]
			},
			{
				text: 'Anexo técnico',
				items: [
					{ text: 'Getting Started', link: '/getting-started' },
					{ text: 'Runbook', link: '/operacion/' },
					{ text: 'QA y validación', link: '/operacion/qa' },
					{ text: 'Release', link: '/operacion/release' }
				]
			}
		],
		search: {
			provider: 'local'
		}
	}
};
