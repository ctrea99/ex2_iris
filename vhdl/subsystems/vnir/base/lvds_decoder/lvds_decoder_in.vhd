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
use work.lvds_decoder_pkg.all;
use work.LVDS_data_array_pkg.all;
use work.logic_types.all;

entity lvds_decoder_in is
generic (
    FRAGMENT_WIDTH  : integer;
    PIXEL_BITS      : integer;
    FIFO_BITS       : integer
);
port (
    clock           : out std_logic;
    reset_n         : in std_logic;

    lvds_data       : in std_logic_vector;
    lvds_control    : in std_logic;
    lvds_clock      : in std_logic;
    
    start_align     : in std_logic;
    
    to_fifo         : out std_logic_vector(FIFO_BITS-1 downto 0)
);
end entity lvds_decoder_in;


architecture rtl of lvds_decoder_in is

    constant CTRL_TRAINING_PATTERN : std_logic_vector(PIXEL_BITS-1 downto 0) := (9 => '1', others => '0');
    constant DATA_TRAINING_PATTERN : std_logic_vector(PIXEL_BITS-1 downto 0) := std_logic_vector(to_unsigned(85, PIXEL_BITS));

    component lvds_reader_top is
    generic (
        NUM_CHANNELS            : integer := FRAGMENT_WIDTH;

        -- ALTLVDS and the sensor use different bit orderings
        DATA_TRAINING_PATTERN   : std_logic_vector := bitreverse(DATA_TRAINING_PATTERN);
        CTRL_TRAINING_PATTERN   : std_logic_vector := bitreverse(CTRL_TRAINING_PATTERN)
    );
    port (
        reset_n                 : in std_logic;
        lvds_data_in            : in std_logic_vector(NUM_CHANNELS-1 downto 0);
        lvds_ctrl_in            : in std_logic;
        lvds_clock_in           : in std_logic;
        alignment_done          : out std_logic;
        cmd_start_align         : in  std_logic;
        word_alignment_error    : out std_logic;
        pll_locked              : out std_logic;
        lvds_parallel_clock     : out std_logic;
        lvds_parallel_data      : out t_lvds_data_array(NUM_CHANNELS-1 downto 0)(PIXEL_BITS-1 downto 0);
        lvds_parallel_ctrl      : out std_logic_vector(PIXEL_BITS-1 downto 0)
    );
    end component lvds_reader_top;
    
    signal align_done  : std_logic;

    signal lvds_parallel_data : t_lvds_data_array(FRAGMENT_WIDTH-1 downto 0)(PIXEL_BITS-1 downto 0);
    signal lvds_parallel_ctrl : std_logic_vector(PIXEL_BITS-1 downto 0);

    signal data_flat_ordered : std_logic_vector(FRAGMENT_WIDTH*PIXEL_BITS-1 downto 0);
    signal ctrl_flat_ordered : std_logic_vector(PIXEL_BITS-1 downto 0);

begin

    lvds_reader_inst : lvds_reader_top port map (
        reset_n => reset_n,
        lvds_data_in => lvds_data,
        lvds_ctrl_in => lvds_control,
        lvds_clock_in => lvds_clock,
        alignment_done => align_done,
        cmd_start_align => start_align,
        word_alignment_error => open,  -- TODO: use this output
        pll_locked => open,  -- TODO: use this output
        lvds_parallel_clock => clock,
        lvds_parallel_data => lvds_parallel_data,
        lvds_parallel_ctrl => lvds_parallel_ctrl
    );

    -- ALTLVDS and the sensor use different bit orderings
    data_flat_ordered <= flatten(bitreverse(lvds_parallel_data));
    ctrl_flat_ordered <= bitreverse(lvds_parallel_ctrl);

    -- data_flat_ordered <= flatten(bitreverse(lvds_parallel_data));
    -- ctrl_flat_ordered <= bitreverse(lvds_parallel_ctrl);

    fsm : process (clock)
        variable aligned : boolean;
    begin
        if reset_n = '0' then
            aligned := false;
            to_fifo <= (others => '0');
        elsif rising_edge(clock) then
            if start_align = '1' then
                aligned := false;
            elsif align_done = '1' then
                aligned := true;
            end if;

            if aligned then
                to_fifo <= "1" & ctrl_flat_ordered & data_flat_ordered;
            else
                to_fifo <= (others => '0');
            end if;
        end if;
    end process fsm;

end architecture rtl;
