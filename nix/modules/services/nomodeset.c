/* Strip DRM_MODE_ATOMIC_ALLOW_MODESET from regular commits; retry with it only
 * if needed. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#define DRM_MODE_ATOMIC_TEST_ONLY 0x0100
#define DRM_MODE_ATOMIC_ALLOW_MODESET 0x0400
typedef struct _drmModeAtomicReq drmModeAtomicReq;
int drmModeAtomicCommit(int fd, drmModeAtomicReq *req, uint32_t flags,
                        void *user_data) {
  static int (*real)(int, drmModeAtomicReq *, uint32_t, void *);
  if (!real)
    real = (int (*)(int, drmModeAtomicReq *, uint32_t, void *))dlsym(
        RTLD_NEXT, "drmModeAtomicCommit");
  if ((flags & DRM_MODE_ATOMIC_ALLOW_MODESET) &&
      !(flags & DRM_MODE_ATOMIC_TEST_ONLY)) {
    if (real(fd, req, flags & ~DRM_MODE_ATOMIC_ALLOW_MODESET, user_data) == 0)
      return 0;
  }
  return real(fd, req, flags, user_data);
}
