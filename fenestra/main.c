
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <stdio.h>

#include <stdio.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

#include <wayland-server-core.h>

static lua_State *L;

int intrp_open_server_socket(char * pathname)
{
    struct sockaddr_un address;
    int socket_fd;
    
    socket_fd = socket(PF_UNIX, SOCK_STREAM, 0);
    if(socket_fd < 0) {
	printf("socket() failed\n");
	return 1;
    } 
    
    unlink(pathname);
    
    /* start with a clean address structure */
    memset(&address, 0, sizeof(struct sockaddr_un));
    
    address.sun_family = AF_UNIX;
    strncpy(address.sun_path, pathname, (sizeof address.sun_path));
    
    if(bind(socket_fd, (struct sockaddr *) &address, 
	    sizeof(struct sockaddr_un)) != 0) {
	printf("bind() failed\n");
	return -1;
    }
    
    if(listen(socket_fd, 5) != 0) {
	printf("listen() failed\n");
	return -1;
    }

    return socket_fd;
}
int intrp_socket_read_expr(int fd, unsigned int mask, void *data) {
    struct wl_event_source *event_source = *((struct wl_event_source **) data);
    char buf[1024];
    int bytes;
    int is_open = 0;
    while((bytes = read(fd, buf, sizeof buf)) > 0) {
	is_open = 1;
	buf[bytes]='\0';
	printf("read %d bytes from socket fd %d\n", bytes, fd);
	(void) luaL_dostring(L, buf);
    }
    if(! is_open) {
	// zero bytes read straight after accept
	printf("socket fd %d probably closed by peer\n", fd);
	close(fd);
	if(event_source) wl_event_source_remove(event_source);
	free(data);
    }
    return 0;
}

    
int intrp_socket_accept_client(int socket_fd, unsigned int mask, void *data)
{
    struct wl_event_loop *event_loop = (struct wl_event_loop *)data;

    int connection_fd = accept(socket_fd, NULL, 0);
    if(connection_fd > 0) {
	struct wl_event_source **data =
	    calloc(sizeof (struct wl_event_source *), 1);
	printf("accepted %d on %d, %p\n",
	       connection_fd, socket_fd, event_loop);

	struct wl_event_source *s;
	s = wl_event_loop_add_fd(event_loop, connection_fd,
				 WL_EVENT_READABLE,
				 intrp_socket_read_expr,
				 data);
	*data = s;
	printf("added client %p\n",s);
    }    
    return 0; 
}


struct lua_wl_listener {
    struct wl_listener listener;
    struct lua_State *L;
    int lua_fn_ref;
};

static void forward_signal_to_lua(struct wl_listener *l, void *d)
{
    printf("made it to "  __FILE__ ": %d\n",  __LINE__ );
    struct lua_wl_listener * listener = ((struct lua_wl_listener *)l);
    int r = listener->lua_fn_ref;
    struct lua_State *L = listener->L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
    lua_pushlightuserdata(L, d);
    lua_pcall(L, 1, 0, 0);
}

static int make_listener(lua_State *L)
{
    // FIXME this allocs RAM and creates refs, and never releases
    // either
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    struct lua_wl_listener *listener =
	calloc(sizeof (struct lua_wl_listener ),1);
    listener->listener.notify = forward_signal_to_lua;
    listener->L = L;
    listener->lua_fn_ref = ref;
    // return l as a lightuserdata
    lua_pushlightuserdata(L, listener);
    return 1;
}

static int signal_add(lua_State *L)
{
    // first arg: lightuserdata to the signal (data pointer)
    // second arg: as returned by make_listener
    // returns nothing interesting
    void * signal = lua_touserdata(L, 1);
    void * listener = lua_touserdata(L, 2);
    lua_pop(L, 2);
  
    wl_signal_add((struct wl_signal *) signal,
		  (struct wl_listener *) listener );
    return 0; 
}

int main()
{
    int status, result;

    /*
     * All Lua contexts are held in this structure. We work with it almost
     * all the time.
     */
    L = luaL_newstate();

    luaL_openlibs(L); /* Load Lua libraries */

    /* Load the file containing the script we are going to run */
    status = luaL_loadfile(L, "init.lua");
    if (status) {
        /* If something went wrong, error message is at the top of */
        /* the stack */
        fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    /* Ask Lua to run our little script */
    result = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (result) {
        fprintf(stderr, "Failed to run script: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    printf("Script returned: %.0f\n", lua_tonumber(L, -1));
    lua_pop(L, 1);  /* Take the returned value out of the stack */

    return 0;
}
