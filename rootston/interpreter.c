
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
	luaL_dostring(L, buf);
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

int
intrp_init(void)
{
    int status, result, i;
    double sum;

    /*
     * All Lua contexts are held in this structure. We work with it almost
     * all the time.
     */
    L = luaL_newstate();

    luaL_openlibs(L); /* Load Lua libraries */

    /* Load the file containing the script we are going to run */
    status = luaL_loadfile(L, "fenestra.lua");
    if (status) {
        /* If something went wrong, error message is at the top of */
        /* the stack */
        fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    /*
     * Ok, now here we go: We pass data to the lua script on the stack.
     * That is, we first have to prepare Lua's virtual stack the way we
     * want the script to receive it, then ask Lua to run it.
     */
    lua_newtable(L);    /* We will pass a table */

    /*
     * To put values into the table, we first push the index, then the
     * value, and then call lua_rawset() with the index of the table in the
     * stack. Let's see why it's -3: In Lua, the value -1 always refers to
     * the top of the stack. When you create the table with lua_newtable(),
     * the table gets pushed into the top of the stack. When you push the
     * index and then the cell value, the stack looks like:
     *
     * <- [stack bottom] -- table, index, value [top]
     *
     * So the -1 will refer to the cell value, thus -3 is used to refer to
     * the table itself. Note that lua_rawset() pops the two last elements
     * of the stack, so that after it has been called, the table is at the
     * top of the stack.
     */
    for (i = 1; i <= 5; i++) {
        lua_pushnumber(L, i);   /* Push the table index */
        lua_pushnumber(L, i*2); /* Push the cell value */
        lua_rawset(L, -3);      /* Stores the pair in the table */
    }

    /* By what name is the script going to reference our table? */
    lua_setglobal(L, "foo");

    /* Ask Lua to run our little script */
    result = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (result) {
        fprintf(stderr, "Failed to run script: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    /* Get the returned value at the top of the stack (index -1) */
    sum = lua_tonumber(L, -1);

    printf("Script returned: %.0f\n", sum);

    lua_pop(L, 1);  /* Take the returned value out of the stack */


    //
    
    return 0;
}

struct lua_wl_listener {
    struct wl_listener listener;
    void * lua_fn;
};

static void forward_signal_to_lua(struct wl_listener *l, void *d)
{
    void * lua_fn = ((struct lua_wl_listener *)l)->lua_fn;
    printf("(not) calling lua callback %p with %p\n", lua_fn, d);
}


struct wl_listener *intrp_make_listener(char *lua_fn_name)
{
    struct lua_wl_listener *l = calloc(sizeof (struct lua_wl_listener ),1);
    l->listener.notify = forward_signal_to_lua;
    l->lua_fn = 0; // lookup(lua_fn_name);
    return (struct wl_listener *)l;
}

