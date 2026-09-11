/* Native test fixture, loaded only in the disposable Nautilus mount namespace. */
#include <adwaita.h>
#include <gmodule.h>
#include <stdio.h>
static int window_index = -1;

static GtkWidget *find_view (GtkWidget *w)
{
    if (!gtk_widget_get_mapped(w)) return NULL;
    if (gtk_widget_has_css_class (w, "nautilus-grid-view") ||
        gtk_widget_has_css_class (w, "nautilus-list-view")) return w;
    for (GtkWidget *c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c)) {
        GtkWidget *v = find_view (c);
        if (v) return v;
    }
    return NULL;
}
static GtkSelectionModel *find_model (GtkWidget *w)
{
    if (GTK_IS_GRID_VIEW(w)) return gtk_grid_view_get_model(GTK_GRID_VIEW(w));
    if (GTK_IS_COLUMN_VIEW(w)) return gtk_column_view_get_model(GTK_COLUMN_VIEW(w));
    for(GtkWidget *c=gtk_widget_get_first_child(w);c;c=gtk_widget_get_next_sibling(c)) {
        GtkSelectionModel *m=find_model(c);if(m)return m;
    }
    return NULL;
}
static GtkWidget *find_scroll (GtkWidget *w)
{
    if (GTK_IS_SCROLLED_WINDOW (w)) return w;
    for (GtkWidget *c = gtk_widget_get_first_child (w); c; c = gtk_widget_get_next_sibling (c)) {
        GtkWidget *v = find_scroll (c);
        if (v) return v;
    }
    return NULL;
}
static void dump (GtkWidget *w, GString *s, int depth)
{
    g_auto(GStrv) classes = gtk_widget_get_css_classes (w);
    g_autofree char *joined = g_strjoinv (" ",classes);
    g_string_append_printf (s,"%*s%s[%s] #%s .%s %dx%d visible=%d\n",depth,"",G_OBJECT_TYPE_NAME(w),gtk_widget_class_get_css_name(GTK_WIDGET_GET_CLASS(w)),
        gtk_widget_get_name(w),joined,gtk_widget_get_width(w),gtk_widget_get_height(w),gtk_widget_get_visible(w));
    for (GtkWidget *c=gtk_widget_get_first_child(w);c;c=gtk_widget_get_next_sibling(c)) dump(c,s,depth+1);
}
static gboolean tick (gpointer unused)
{
    (void) unused;
    const char *dir = g_getenv ("LYRA_NATIVE_PROBE");
    g_autofree char *request = g_build_filename (dir,"request",NULL);
    g_autofree char *reply = g_build_filename (dir,"reply",NULL);
    g_autofree char *command = NULL;
    if (!g_file_get_contents (request,&command,NULL,NULL)) return G_SOURCE_CONTINUE;
    GListModel *windows=gtk_window_get_toplevels();
    g_autoptr(GtkWindow) window=NULL;
    int found=0;
    for (guint i=0;i<g_list_model_get_n_items(windows);i++) {
        GtkWindow *candidate=g_list_model_get_item(windows,i);
        if (gtk_widget_get_mapped(GTK_WIDGET(candidate)) && find_view(GTK_WIDGET(candidate))) {
            if(window_index>=0) {
                if(found++==window_index) {window=candidate;break;}
                g_object_unref(candidate);continue;
            }
            if (gtk_window_is_active(candidate)) {g_clear_object(&window);window=candidate;break;}
            if (!window) {window=candidate;continue;}
        }
        g_object_unref(candidate);
    }
    if (!window) return G_SOURCE_CONTINUE;
    remove(request);
    GtkWidget *w=GTK_WIDGET(window), *view=find_view(w);
    gboolean ok=TRUE;
    if (g_str_has_prefix(command,"capture ")) {
        g_autoptr(GdkPaintable) paintable=gtk_widget_paintable_new(w);
        GtkSnapshot *snapshot=gtk_snapshot_new();
        gdk_paintable_snapshot(paintable,GDK_SNAPSHOT(snapshot),gtk_widget_get_width(w),gtk_widget_get_height(w));
        g_autoptr(GskRenderNode) node=gtk_snapshot_free_to_node(snapshot);
        GskRenderer *renderer=gtk_native_get_renderer(GTK_NATIVE(w));
        g_autoptr(GdkTexture) texture=gsk_renderer_render_texture(renderer,node,NULL);
        ok=gdk_texture_save_to_png(texture,command+8);
    } else if (g_str_equal(command,"dump")) {
        GString *s=g_string_new(NULL);dump(w,s,0);g_file_set_contents(reply,s->str,-1,NULL);g_string_free(s,TRUE);return G_SOURCE_CONTINUE;
    } else if (g_str_has_prefix(command,"window ")) {
        window_index=atoi(command+7);
    } else if (g_str_equal(command,"state")) {
        graphene_rect_t bounds;
        ok=gtk_widget_compute_bounds(view,w,&bounds);
        GtkAdjustment *a=gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(find_scroll(view)));
        GtkSelectionModel *m=find_model(view);
        g_autoptr(GtkBitset) selection=m?gtk_selection_model_get_selection(m):NULL;
        g_autofree char *state=g_strdup_printf("{\"windows\":%u,\"window\":\"%p\",\"scale\":%d,\"x\":%.0f,\"y\":%.0f,\"width\":%.0f,\"height\":%.0f,\"mode\":\"%s\",\"items\":%u,\"selected\":%lu,\"scroll\":%.0f,\"upper\":%.0f,\"page\":%.0f}",
            g_list_model_get_n_items(windows),(void*)w,gtk_widget_get_scale_factor(w),bounds.origin.x,bounds.origin.y,bounds.size.width,bounds.size.height,
            gtk_widget_has_css_class(view,"nautilus-grid-view")?"grid":"list",
            m?g_list_model_get_n_items(G_LIST_MODEL(m)):0,selection?(unsigned long)gtk_bitset_get_size(selection):0,
            gtk_adjustment_get_value(a),gtk_adjustment_get_upper(a),gtk_adjustment_get_page_size(a));
        g_file_set_contents(reply,state,-1,NULL);return G_SOURCE_CONTINUE;
    } else if (g_str_equal(command,"picks")) {
        GString *s=g_string_new(NULL);
        for(int y=30;y<=110;y+=20)for(int x=30;x<=110;x+=20) {
            GtkWidget *picked=gtk_widget_pick(view,gtk_widget_get_width(view)-x,gtk_widget_get_height(view)-y,GTK_PICK_DEFAULT);
            g_string_append_printf(s,"%s\n",picked?G_OBJECT_TYPE_NAME(picked):"none");
        }
        g_file_set_contents(reply,s->str,-1,NULL);g_string_free(s,TRUE);return G_SOURCE_CONTINUE;
    } else if (g_str_equal(command,"custom-on") || g_str_equal(command,"custom-off")) {
        if(g_str_equal(command,"custom-on"))gtk_widget_add_css_class(w,"suppress-lyra");
        else gtk_widget_remove_css_class(w,"suppress-lyra");
    } else if (g_str_has_prefix(command,"search ")) {
        ok=gtk_widget_activate_action(view,"slot.focus-search",NULL);
        GtkWidget *focus=gtk_root_get_focus(GTK_ROOT(w));
        if(ok && GTK_IS_EDITABLE(focus))gtk_editable_set_text(GTK_EDITABLE(focus),command+7);
        else ok=FALSE;
    } else if (g_str_has_prefix(command,"tab ")) {
        ok=gtk_widget_activate_action(w,"win.go-to-tab","i",atoi(command+4));
    } else if (g_str_has_prefix(command,"location ")) {
        g_autofree char *uri=g_filename_to_uri(command+9,NULL,NULL);
        ok=uri && gtk_widget_activate_action(view,"slot.open-location","s",uri);
    } else if (g_str_equal(command,"dark") || g_str_equal(command,"light")) {
        adw_style_manager_set_color_scheme(adw_style_manager_get_default(),g_str_equal(command,"dark")?ADW_COLOR_SCHEME_FORCE_DARK:ADW_COLOR_SCHEME_FORCE_LIGHT);
    } else if (g_str_has_prefix(command,"scroll ")) {
        GtkWidget *scroll=find_scroll(view);
        GtkAdjustment *a=gtk_scrolled_window_get_vadjustment(GTK_SCROLLED_WINDOW(scroll));
        gtk_adjustment_set_value(a,g_str_equal(command+7,"bottom")?gtk_adjustment_get_upper(a)-gtk_adjustment_get_page_size(a):0);
    } else if (g_str_has_prefix(command,"resize ")) {
        int width,height;ok=sscanf(command+7,"%d %d",&width,&height)==2;
        if(ok) gtk_window_set_default_size(window,width,height);
    } else if (g_str_has_prefix(command,"action ")) {
        ok=gtk_widget_activate_action(view,command+7,NULL);
    } else if (g_str_has_prefix(command,"mode ")) {
        gboolean grid=gtk_widget_has_css_class(view,"nautilus-grid-view");
        if(grid!=g_str_equal(command+5,"grid"))
            ok=gtk_widget_activate_action(view,"slot.files-view-mode-toggle",NULL);
    } else ok=FALSE;
    g_file_set_contents(reply,ok?"ok":"failed",-1,NULL);
    return G_SOURCE_CONTINUE;
}
G_MODULE_EXPORT void nautilus_module_initialize(GTypeModule *module) {
    (void)module;if(g_getenv("LYRA_NATIVE_PROBE"))g_timeout_add(100,tick,NULL);
}
G_MODULE_EXPORT void nautilus_module_shutdown(void) {}
G_MODULE_EXPORT void nautilus_module_list_types(const GType **types,int *n) {*types=NULL;*n=0;}
