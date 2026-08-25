// hey there!!
// this is a template for matugen... if you dont want to use matugen i might give a pywal version in the future... just ask :)

pragma Singleton
import QtQuick

QtObject {
    readonly property color colPrimary:          "{{ colors.primary.default.hex }}"
    readonly property color colOnPrimary:        "{{ colors.on_primary.default.hex }}"
    readonly property color colBackground:       "{{ colors.background.default.hex }}"
    readonly property color colSurface:          "{{ colors.surface.default.hex }}"
    readonly property color colOnSurface:        "{{ colors.on_surface.default.hex }}"
    readonly property color colOnSurfaceVariant: "{{ colors.on_surface_variant.default.hex }}"
    readonly property color colOutline:          "{{ colors.outline.default.hex }}"
	readonly property color colSurfaceVariant:   "{{ colors.surface_variant.default.hex }}"
	readonly property color colOnBackground:     "{{ colors.on_background.default.hex }}"
}
