#define WLR_USE_UNSTABLE 1
#define __float128 long double
#define _Float128 long double
#include <quadmath.h>
#include <wlr/types/wlr_pointer.h>
#include <wlr/types/wlr_compositor.h>
#include <wlr/types/wlr_cursor.h>
#include <wlr/types/wlr_surface.h>
#include <wlr/types/wlr_idle.h>
#include <wlr/types/wlr_xcursor_manager.h>
#include <wlr/types/wlr_xdg_shell.h>
#include <wlr/types/wlr_xdg_shell_v6.h>
#include <wlr/xcursor.h>
#include <wlr/backend.h>
#include <wlr/util/log.h>

#include <sys/types.h>
#include <unistd.h>

