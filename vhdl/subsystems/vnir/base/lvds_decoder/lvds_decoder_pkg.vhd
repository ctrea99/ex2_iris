----------------------------------------------------------------
-- Copyright 2020 University of Alberta

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--     http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vnir_base.all;

package lvds_decoder_pkg is

    type status_t is record
        PLACEHOLDER : std_logic;
    end record status_t;

    pure function unflatten_to_fragment(fragment_flat : std_logic_vector; PIXEL_BITS : integer) return pixel_vector_t;

    pure function rotate_right(bits : std_logic_vector; i : integer) return std_logic_vector;
    pure function calc_align_offset(control : std_logic_vector;
                                    control_target : std_logic_vector)
                                    return integer;

end package lvds_decoder_pkg;


package body lvds_decoder_pkg is

    pure function unflatten_to_fragment(fragment_flat : std_logic_vector; PIXEL_BITS : integer
    ) return pixel_vector_t is
        constant FRAGMENT_WIDTH : integer := fragment_flat'length / PIXEL_BITS;
        variable fragment : pixel_vector_t(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    begin
        for i_pixel in fragment'range loop
            for i_bit in fragment(0)'range loop
                fragment(i_pixel)(i_bit) := fragment_flat(i_bit + i_pixel * PIXEL_BITS);
            end loop;
        end loop;
        return fragment;
    end function unflatten_to_fragment;

    pure function rotate_right(bits : std_logic_vector; i : integer) return std_logic_vector is
    begin
        return std_logic_vector(rotate_right(unsigned(bits), i));
    end function rotate_right;

    pure function calc_align_offset(control : std_logic_vector; control_target : std_logic_vector)
                                    return integer is
    begin
        for i in 0 to control'length-1 loop
            if rotate_right(control, i) = control_target then
                return i;
            end if;
        end loop;

        report "Can't compute align offset" severity failure;
        return 0;  -- TODO: trigger some kind of error if we get here
    end function calc_align_offset;

end package body lvds_decoder_pkg;
