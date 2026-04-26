/*
 * Photon - Colorwheel support (Nether shadow)
 * Nether has no sun shadows in Photon (shadow.vsh discards),
 * but Colorwheel still needs this program to exist so it doesn't fall back.
 */

#define WORLD_NETHER
#define fsh
#include "/program/clrwl_shadow.fsh"
