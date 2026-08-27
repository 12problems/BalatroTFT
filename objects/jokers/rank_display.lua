-- Shows a Joker's Rank (1/2/3 stars, joker-ranking.md) via the JokerDisplay
-- mod (W:\...\Mods\JokerDisplay), rather than inventing a second on-card UI
-- element competing for the same space. Soft dependency -- entirely guarded
-- behind `if JokerDisplay then`, so this file is a complete no-op (not an
-- error) when JokerDisplay isn't installed; no hard BalatroTFT.json
-- dependency added, matching how console-only info would otherwise be the
-- only way to see this (exactly what the player asked to avoid).
--
-- COMPATIBILITY, not replacement: JokerDisplay's own extension point for
-- "content independent of which Joker this is" is
-- JokerDisplay.Global_Definitions.Replace -- but Replace entries REPLACE a
-- card's own text/reminder/extra wholesale (display_functions.lua's
-- initialize_joker_display: `definition_text = replace_text or
-- joker_display_definition and (...)`), which would blow away whatever a
-- Joker's own real JokerDisplay definition already shows (e.g. a vanilla
-- xMult Joker's live accumulated value). Instead this wraps
-- Card:calculate_joker_display and Card:initialize_joker_display directly --
-- the same two functions JokerDisplay itself defines and calls internally --
-- calling straight through to JokerDisplay's real logic FIRST, then
-- ADDING our own extra row via the same public JokerDisplayBox:add_extra API
-- JokerDisplay uses for its own rows. Both mods' info ends up in the same
-- box, same "extra" section, one row each -- literally "using the same
-- space," not a second floating element.
--
-- LIVE UPDATES: follows JokerDisplay's own idiomatic pattern for anything
-- that changes over time (see display_functions.lua's Perishable/Rental
-- displays) -- store plain strings on card.joker_display_values, refreshed
-- inside calculate_joker_display (already called on JokerDisplay's own
-- throttled per-card update cadence, Card:update), and reference them via
-- JokerDisplay.create_display_text_object's {ref_table, ref_value} live-poll
-- mechanism (UIElement:update_text re-reads ref_table[ref_value] every
-- frame and only rebuilds the text object when it actually changed) -- rather
-- than manually forcing a reload after every merge.
if JokerDisplay then
	local RANK_COLOUR = { [1] = G.C.UI.TEXT_LIGHT, [2] = G.C.BLUE, [3] = G.C.GOLD }

	local function is_real_ranked_joker(self, custom_parent)
		if custom_parent then return false end -- skip Blueprint-copy virtual displays -- rank belongs to the physical card, not a copied ability
		if not TFT.is_run_active() then return false end
		if not self.ability or self.ability.set ~= 'Joker' then return false end
		if not self.config or not self.config.center or self.config.center.key == 'j_tft_traits_engine' then return false end
		return true
	end

	local _tft_orig_calc_joker_display = Card.calculate_joker_display
	function Card:calculate_joker_display(custom_parent)
		_tft_orig_calc_joker_display(self, custom_parent)
		if not is_real_ranked_joker(self, custom_parent) then return end

		local rank = TFT.get_joker_rank(self)
		local max_rank = TFT.MAX_JOKER_RANK
		local mult = TFT.joker_rank_multiplier(self)

		-- Plain string, not localize() -- 'k_rank_ex' isn't a real vanilla or
		-- JokerDisplay localization key and inventing one would need en-us.lua
		-- entries in every supported language to render correctly instead of
		-- falling back to a raw key string.
		self.joker_display_values.tft_rank_text = 'Rank ' .. rank .. '/' .. max_rank

		if rank < max_rank then
			local tier = TFT.get_power_tier(self.config.center.key, self.config.center.rarity)
			local curve = TFT.PowerTierRankMultiplier[tier] or TFT.PowerTierRankMultiplier[1]
			local next_mult = curve[math.min(rank + 1, #curve)]
			-- Real remaining-copies count (3 total for Rank 2, 6 total for
			-- Rank 3 -- objects/jokers/ranking.lua's TFT.copies_to_next_rank),
			-- not a flat "+1" -- copies 4/5 both correctly read "1 more" (they're
			-- one step closer to the 6-copy Rank 3 threshold) while a fresh
			-- Rank 1 single copy reads "2 more" (needs 2 more to reach 3 total).
			local remaining = TFT.copies_to_next_rank(self)
			local copy_word = remaining == 1 and 'copy' or 'copies'
			self.joker_display_values.tft_mult_text = string.format('x%.1f', mult) .. ' -> x' .. string.format('%.1f', next_mult) .. ' (' .. remaining .. ' more ' .. copy_word .. ')'
		else
			self.joker_display_values.tft_mult_text = string.format('x%.1f (MAX)', mult)
		end
	end

	local _tft_orig_init_joker_display = Card.initialize_joker_display
	function Card:initialize_joker_display(custom_parent, stop_calc)
		_tft_orig_init_joker_display(self, custom_parent, stop_calc)
		if not is_real_ranked_joker(self, custom_parent) then return end

		-- Matches JokerDisplay's own row-config convention (reminder_text's
		-- default colour/scale, see display_functions.lua) -- a touch smaller
		-- than JokerDisplay's normal 0.4 text scale so this reads as
		-- supplementary info alongside a Joker's own real display, not a
		-- competing headline.
		local row_config = { scale = 0.32 }
		local extra_rows = {
			{ { ref_table = 'card.joker_display_values', ref_value = 'tft_rank_text', colour = RANK_COLOUR[TFT.get_joker_rank(self)] or G.C.UI.TEXT_LIGHT } },
			{ { ref_table = 'card.joker_display_values', ref_value = 'tft_mult_text', colour = G.C.UI.TEXT_INACTIVE } },
		}

		if self.children.joker_display then
			self.children.joker_display:add_extra(extra_rows, row_config)
			self.children.joker_display:recalculate(true)
		end
		if self.children.joker_display_small then
			self.children.joker_display_small:add_extra(extra_rows, row_config)
			self.children.joker_display_small:recalculate(true)
		end
	end
end
