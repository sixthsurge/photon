#if !defined INCLUDE_MISC_LIGHTNING_FLASH
#define INCLUDE_MISC_LIGHTNING_FLASH

#ifdef LIGHTNING_FLASH
#if defined IS_IRIS
uniform float lightning_flash_iris;
#define LIGHTNING_FLASH_UNIFORM lightning_flash_iris
#else
uniform float lightning_flash_of;
#define LIGHTNING_FLASH_UNIFORM lightning_flash_of
#endif
#else
#define LIGHTNING_FLASH_UNIFORM 0.0
#endif

const float lightning_flash_intensity = LIGHTNING_FLASH_INTENSITY;

#endif // INCLUDE_MISC_LIGHTNING_FLASH
