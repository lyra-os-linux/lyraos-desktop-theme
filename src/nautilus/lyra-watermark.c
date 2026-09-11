/* SPDX-License-Identifier: GPL-3.0-or-later */
#define G_LOG_DOMAIN "lyra-watermark"
#include <gtk/gtk.h>
#include <gmodule.h>

#ifndef LYRA_WATERMARK_PATH
#define LYRA_WATERMARK_PATH "/usr/share/lyra-os-theme/nautilus/watermark-symbolic.svg"
#endif

static GtkCssProvider *provider;
static GdkDisplay *display;
static GSettings *shell_settings;
static GSettings *accessibility;
static gboolean attached;
static guint startup_source;

static gboolean
contains (GSettings *settings, const char *key, const char *value)
{
    g_auto (GStrv) values = g_settings_get_strv (settings, key);
    return g_strv_contains ((const char * const *) values, value);
}

static void
sync_watermark (void)
{
    const char *uuid = "sheliak@lyraos.com.br";
    gboolean enabled = shell_settings &&
        contains (shell_settings, "enabled-extensions", uuid) &&
        !contains (shell_settings, "disabled-extensions", uuid) &&
        !g_settings_get_boolean (shell_settings, "disable-user-extensions") &&
        !(accessibility && g_settings_get_boolean (accessibility, "high-contrast"));
    g_debug ("Watermark enabled=%d attached=%d", enabled, attached);
    if (enabled == attached)
        return;
    if (enabled)
        gtk_style_context_add_provider_for_display (display, GTK_STYLE_PROVIDER (provider),
                                                   GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    else
        gtk_style_context_remove_provider_for_display (display, GTK_STYLE_PROVIDER (provider));
    attached = enabled;
}

static void
settings_changed (GSettings *settings, const char *key, gpointer data)
{
    (void) settings;
    (void) key;
    (void) data;
    sync_watermark ();
}

static GSettings *
open_settings (const char *name)
{
    GSettingsSchemaSource *source = g_settings_schema_source_get_default ();
    g_autoptr (GSettingsSchema) schema = source ?
        g_settings_schema_source_lookup (source, name, TRUE) : NULL;
    return schema ? g_settings_new_full (schema, NULL, NULL) : NULL;
}

static gboolean
start_watermark (gpointer data)
{
    (void) data;
    startup_source = 0;
    if (provider)
        return G_SOURCE_REMOVE;
    const char *desktop = g_getenv ("XDG_CURRENT_DESKTOP");
    g_autofree char *upper = g_ascii_strup (desktop ? desktop : "", -1);
    g_auto (GStrv) desktops = g_strsplit (upper, ":", -1);
    const char *other_desktops[] = {"KDE", "PLASMA", "XFCE", "LXQT", "MATE", "CINNAMON"};
    for (guint i = 0; i < G_N_ELEMENTS (other_desktops); i++)
        if (g_strv_contains ((const char * const *) desktops, other_desktops[i]))
            return G_SOURCE_REMOVE;
    if (!g_strv_contains ((const char * const *) desktops, "GNOME"))
        return G_SOURCE_REMOVE;
    display = gdk_display_get_default ();
    g_debug ("Display=%p asset=%d", (void *) display, g_file_test (LYRA_WATERMARK_PATH, G_FILE_TEST_IS_REGULAR));
    if (!display || !g_file_test (LYRA_WATERMARK_PATH, G_FILE_TEST_IS_REGULAR))
        return G_SOURCE_REMOVE;
    g_object_ref (display);
    provider = gtk_css_provider_new ();
    /* Paint the fixed viewport, never a scrolling grid/list or an input overlay.
     * Scope to Files windows, excluding the Nautilus file chooser and dialogs. */
    gtk_css_provider_load_from_string (provider,
        "window.nautilus-window .nautilus-grid-view > overlay > scrolledwindow,"
        "window.nautilus-window .nautilus-list-view > overlay > scrolledwindow,"
        "window.nautilus-window .nautilus-grid-view > overlay > statuspage > scrolledwindow,"
        "window.nautilus-window .nautilus-list-view > overlay > statuspage > scrolledwindow {"
        "background-image: -gtk-recolor(url('file://" LYRA_WATERMARK_PATH "'));"
        "background-repeat: no-repeat;"
        "background-size: 96px 96px;"
        "background-position: calc(100% - 24px) calc(100% - 24px);"
        "}");
    shell_settings = open_settings ("org.gnome.shell");
    accessibility = open_settings ("org.gnome.desktop.a11y.interface");
    if (shell_settings)
        g_signal_connect (shell_settings, "changed", G_CALLBACK (settings_changed), NULL);
    if (accessibility)
        g_signal_connect (accessibility, "changed::high-contrast", G_CALLBACK (settings_changed), NULL);
    sync_watermark ();
    return G_SOURCE_REMOVE;
}

G_MODULE_EXPORT void
nautilus_module_initialize (GTypeModule *module)
{
    (void) module;
    /* Modules may be loaded before GtkApplication has opened its display. */
    if (!startup_source && !provider)
        startup_source = g_idle_add (start_watermark, NULL);
}

G_MODULE_EXPORT void
nautilus_module_shutdown (void)
{
    if (startup_source) {
        g_source_remove (startup_source);
        startup_source = 0;
    }
    if (attached)
        gtk_style_context_remove_provider_for_display (display, GTK_STYLE_PROVIDER (provider));
    attached = FALSE;
    g_clear_object (&shell_settings);
    g_clear_object (&accessibility);
    g_clear_object (&provider);
    g_clear_object (&display);
}

G_MODULE_EXPORT void
nautilus_module_list_types (const GType **types, int *num_types)
{
    /* The loader supports modules without file/menu providers. Branding has no
     * file operations or menu entries and does not need a dummy provider. */
    *types = NULL;
    *num_types = 0;
}
