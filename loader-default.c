#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

__attribute__((constructor))
static void select_bundled_vulkan_driver(void)
{
    if (getenv("VK_DRIVER_FILES") || getenv("VK_ICD_FILENAMES"))
        return;

    Dl_info info;
    if (!dladdr((const void *)select_bundled_vulkan_driver, &info))
        return;

    const char *slash = strrchr(info.dli_fname, '/');
    if (!slash)
        return;

    char manifest[PATH_MAX];
    int length = snprintf(manifest, sizeof(manifest), "%.*s/kosmickrisp/kosmickrisp_icd.json",
                          (int)(slash - info.dli_fname), info.dli_fname);
    if (length > 0 && (size_t)length < sizeof(manifest))
        setenv("VK_DRIVER_FILES", manifest, 0);
}
