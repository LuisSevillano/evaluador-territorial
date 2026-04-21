import type { SheetTab } from '$lib/state/urlState';

export const panelStateOnSelect = (
	currentTab: SheetTab,
	isMobile: boolean
): { tab: SheetTab; open: boolean } => {
	if (!isMobile) return { tab: currentTab, open: false };
	return { tab: 'sel', open: true };
};

export const panelStateOnClearSelection = (
	currentTab: SheetTab,
	isMobile: boolean
): { tab: SheetTab; open: boolean } => {
	if (!isMobile) return { tab: currentTab, open: false };
	return { tab: currentTab, open: false };
};

export const panelStateOnTabClick = (tab: SheetTab): { tab: SheetTab; open: boolean } => ({
	tab,
	open: true
});
