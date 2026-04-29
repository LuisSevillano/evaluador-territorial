export default {
  title: 'Observatorio Territorial',
  description: 'Documentacion tecnica y metodologica de El Buen Vivir',
  lang: 'es-ES',
  base: '/docs/',
  appearance: 'dark',
  themeConfig: {
    nav: [
      { text: 'Atlas', link: 'https://observatorio-territorial.netlify.app/' }
    ],
    sidebar: [
      {
        text: 'Entender el atlas',
        items: [
          { text: 'Introduccion', link: '/' },
          { text: 'Arquitectura del atlas', link: '/arquitectura' },
          { text: 'Por que confiar en el analisis', link: '/analisis-objetividad' },
          { text: 'Metodologia y limites', link: '/metodologia' }
        ]
      },
      {
        text: 'Pipeline de datos',
        items: [
          { text: 'Vision general', link: '/pipeline/' },
          { text: 'Trazabilidad', link: '/pipeline/trazabilidad' },
          { text: 'Fuentes de datos', link: '/pipeline/fuentes' },
          { text: 'Scripts detallados', link: '/pipeline/scripts-detalle' }
        ]
      },
      {
        text: 'Indicadores',
        items: [
          { text: 'Vista general', link: '/indicadores/' },
          { text: 'Diccionario completo', link: '/indicadores/data-dictionary' },
          { text: 'Clima', link: '/indicadores/clima' },
          { text: 'Accesibilidad', link: '/indicadores/accesibilidad' },
          { text: 'Naturaleza y rios', link: '/indicadores/naturaleza-rios' },
          { text: 'Score compuesto', link: '/indicadores/score' }
        ]
      },
      {
        text: 'Anexo tecnico',
        items: [
          { text: 'Getting Started tecnico', link: '/getting-started' },
          { text: 'Runbook', link: '/operacion/' },
          { text: 'QA y validacion', link: '/operacion/qa' },
          { text: 'Release', link: '/operacion/release' }
        ]
      }
    ],
    search: {
      provider: 'local'
    }
  }
}
