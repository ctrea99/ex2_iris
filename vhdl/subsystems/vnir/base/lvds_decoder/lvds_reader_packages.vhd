library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.logic_types.all;

package LVDS_data_array_pkg is
	type t_lvds_data_array is array(natural range <>) of std_logic_vector;

	pure function bitreverse(lvds_data : t_lvds_data_array) return t_lvds_data_array;
    pure function flatten(lvds_data : t_lvds_data_array) return std_logic_vector;
end package;

package body LVDS_data_array_pkg is

	pure function bitreverse(lvds_data : t_lvds_data_array) return t_lvds_data_array is
        variable lvds_data_reversed : t_lvds_data_array(lvds_data'range)(lvds_data(0)'range);
    begin
        for i in lvds_data'range loop
            lvds_data_reversed(i) := bitreverse(lvds_data(i));
        end loop;
        return lvds_data_reversed;
    end function bitreverse;

    pure function flatten(lvds_data : t_lvds_data_array) return std_logic_vector is
        constant FLAT_BITS : integer := lvds_data'length*lvds_data(0)'length;
        variable flat : std_logic_vector(FLAT_BITS-1 downto 0);
    begin
        for i_channel in lvds_data'range loop
            for i_bit in lvds_data(0)'range loop
                flat(i_bit + i_channel * lvds_data(0)'length) := lvds_data(i_channel)(i_bit);
            end loop;
        end loop;
        return flat;
	end function flatten;
	
end package body LVDS_data_array_pkg;