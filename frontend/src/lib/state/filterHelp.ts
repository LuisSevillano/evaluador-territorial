export const FILTER_HELP = {
	search: 'Filtra por nombre del municipio o provincia. No cambia el score, solo lo que se muestra.',
	province: 'Muestra solo municipios de la provincia seleccionada.',
	accessibility:
		'Limita por tiempo de desplazamiento al municipio. Menor tiempo = filtro más estricto.',
	precip: 'Excluye municipios con menos lluvia anual que este umbral.',
	winter: 'Excluye municipios con invierno medio por debajo de este valor.',
	summer: 'Excluye municipios con verano medio por encima de este valor.',
	amplitude:
		'Diferencia entre la temperatura media de julio y enero. Cuanto menor, más estable es el clima anual.',
	minScore: 'Oculta municipios con score global inferior al valor elegido.',
	mapColor: 'Elige de qué manera quieres colorear los municipios.'
} as const;
