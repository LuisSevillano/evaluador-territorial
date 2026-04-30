export type ReliefTone = 'flat' | 'mild' | 'mountain' | 'very-mountain';

export type ReliefVariant = {
	tone: 'flat' | 'mild' | 'mountain' | 'very-mountain';
	color: string;
	label: string;
};

const FLAT_THRESHOLD = 0.25;
const MILD_THRESHOLD = 0.50;
const MOUNTAIN_THRESHOLD = 0.75;

export const reliefVariantFromNorm = (norm: number | undefined): ReliefVariant => {
	if (norm === undefined || !Number.isFinite(norm)) {
		return { tone: 'flat', color: '#9ca3af', label: 'Sin datos' };
	}

	if (norm < FLAT_THRESHOLD) {
		return { tone: 'flat', color: '#22c55e', label: 'Zona muy llana' };
	}

	if (norm < MILD_THRESHOLD) {
		return { tone: 'mild', color: '#a16207', label: 'Zona llana' };
	}

	if (norm < MOUNTAIN_THRESHOLD) {
		return { tone: 'mountain', color: '#854d0e', label: 'Zona montañosa' };
	}

	return { tone: 'very-mountain', color: '#7c3aed', label: 'Zona muy montañosa' };
};