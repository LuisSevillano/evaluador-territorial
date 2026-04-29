export default {
	title: 'Observatorio Territorial',
	description: 'Documentación práctica del Atlas / Evaluador Territorial de El Buen Vivir',
	lang: 'es-ES',
	base: '/docs/',
	appearance: 'dark',
	head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/docs/favicon-docs.svg' }]],
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
					{ text: 'Guía Desktop', link: '/uso-atlas/desktop' },
					{ text: 'Guía Mobile', link: '/uso-atlas/mobile' },
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
