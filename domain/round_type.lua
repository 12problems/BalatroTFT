-- Round-type enum. String values are namespaced (not just 'pve'/'pvp') since these
-- may end up compared against/broadcast alongside other mods' MPAPI state.
TFT.RoundType = {
	PVE = 'tft_pve',
	PVP = 'tft_pvp',
	CAROUSEL = 'tft_carousel',
}
