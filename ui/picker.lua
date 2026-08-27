-- Shared "centered popup, list of clickable rows" overlay -- the same visual
-- pattern used by both the Carousel and Augment Checkpoint screens in the
-- reference screenshots from the earlier (lost) implementation. Built on
-- vanilla's real G.FUNCS.overlay_menu/exit_overlay_menu and UIBox_button.

-- opts: { title, subtitle, subtitle_colour, rows = {{label={...}, button=G.FUNCS
-- name, colour, ref_table, id}}, footer_rows = {...}, no_esc }
--
-- CORRECTED via live testing: every real vanilla overlay_menu call site passes
-- `definition = create_UIBox_xyz()` -- an ALREADY-CALLED function, i.e. the
-- resolved node-tree table itself. The first draft here passed a lazy
-- `function() ... end` closure instead, which UIBox's constructor doesn't call
-- for you -- it just tries to walk the function value as if it were a node
-- table, crashing (engine/ui.lua's set_parent_child indexing a function).
function TFT.build_picker_node_tree(opts)
	local nodes = {
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			{ n = G.UIT.T, config = { text = opts.title, scale = 0.6, colour = G.C.UI.TEXT_LIGHT } },
		} },
	}
	if opts.subtitle then
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
			{ n = G.UIT.T, config = { text = opts.subtitle, scale = 0.5, colour = opts.subtitle_colour or G.C.WHITE } },
		} })
	end
	for _, row in ipairs(opts.rows or {}) do
		-- A row can be a fully custom node tree (e.g. stage_overview.lua's real
		-- blind-card rows) instead of a plain clickable button -- used for
		-- informational rows, not choices.
		if row.custom_node then
			table.insert(nodes, row.custom_node)
		else
			table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.06 }, nodes = {
				UIBox_button({
					button = row.button,
					label = row.label,
					minw = row.minw or 5.5,
					colour = row.colour or G.C.GREY,
					ref_table = row.ref_table,
					id = row.id,
					scale = 0.4,
				}),
			} })
		end
	end
	for _, row in ipairs(opts.footer_rows or {}) do
		table.insert(nodes, { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = {
			UIBox_button({
				button = row.button,
				label = row.label,
				minw = row.minw or 5.5,
				colour = row.colour or G.C.BLUE,
				ref_table = row.ref_table,
				id = row.id,
			}),
		} })
	end
	return {
		n = G.UIT.ROOT,
		config = { align = 'cm', colour = G.C.CLEAR, minw = 8 },
		nodes = {
			{ n = G.UIT.C, config = { align = 'cm', padding = 0.3, r = 0.1, colour = G.C.L_BLACK, minw = 8 }, nodes = nodes },
		},
	}
end

function TFT.show_picker_overlay(opts)
	G.FUNCS.overlay_menu({
		config = { no_esc = opts.no_esc },
		definition = TFT.build_picker_node_tree(opts),
	})
end

function TFT.close_picker_overlay()
	G.FUNCS.exit_overlay_menu()
end
