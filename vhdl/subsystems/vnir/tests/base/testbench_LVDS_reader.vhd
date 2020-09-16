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

library std;
use std.env.stop;

use work.LVDS_data_array_pkg.all;

entity testbench_LVDS_reader is

end entity;


architecture tb of testbench_LVDS_reader is

    -- Up to 240 MHz
    constant clockPeriod        : time := 4.2 ns;

    -- Main system clock and reset
    signal system_clock         : std_logic := '0';
    signal system_reset         : std_logic := '0';
    
    -- Input from LVDS data and clock pins
    signal lvds_data_in         : std_logic_vector (15 downto 0) := (others => '0');
    signal lvds_ctrl_in         : std_logic := '0';
    signal lvds_clock_in        : std_logic := '0';
    
    -- Word alignment signals
    signal alignment_done       : std_logic;
    signal cmd_start_align      : std_logic := '0';
    
    -- LVDS reader status signals
    signal pll_locked           : std_logic;
    signal word_alignment_error : std_logic;
    
    -- Enable/disable LVDS input clock signal
    signal clock_enable         : std_logic := '1';
    
    signal lvds_parallel_clock  : std_logic;
    
    signal lvds_parallel_data   : t_lvds_data_array(15 downto 0)(9 downto 0);
    signal lvds_parallel_ctrl   : std_logic_vector(9 downto 0);
    
    constant trainingPattern_data : std_logic_vector (9 downto 0) := "0001010101";
    constant trainingPattern_ctrl : std_logic_vector (9 downto 0) := (9 => '1', others => '0');

    component lvds_reader_top is
        generic (
            DATA_TRAINING_PATTERN   : std_logic_vector (9 downto 0) := trainingPattern_data;
            CTRL_TRAINING_PATTERN   : std_logic_vector (9 downto 0) := trainingPattern_ctrl
        );
        port(
            reset_n                 : in std_logic;
            
            lvds_data_in            : in std_logic_vector (15 downto 0);
            lvds_ctrl_in            : in std_logic;
            lvds_clock_in           : in std_logic;
            
            alignment_done          : out std_logic;
            cmd_start_align         : in  std_logic;
            
            word_alignment_error    : out std_logic;
            pll_locked              : out std_logic;
            
            lvds_parallel_clock     : out std_logic;
            
            lvds_parallel_data      : out t_lvds_data_array(15 downto 0)(9 downto 0);
            lvds_parallel_ctrl      : out std_logic_vector(9 downto 0)
        );
    end component;

    signal generate_alignment_error : boolean := false;

begin

    -- Generate main and lvds clock signals
    clockGen : process
        subtype t_clockDivider is integer range 4 downto 0;
        variable clockDivider : t_clockDivider := 0;
    begin
        wait for clockPeriod / 2;
        if (clock_enable = '1') then
            lvds_clock_in <= not lvds_clock_in;
        end if;
        
        if(clockDivider = 4) then
            system_clock <= not system_clock;
            clockDivider := 0;
        else
            clockDivider := clockDivider + 1;        
        end if;    
    end process clockGen;
    
    
    
    -- Input CMV4000 training pattern to the SERDES module
    generateTrainingPattern : process(lvds_clock_in)
        
        subtype t_trainingPatternIndex is integer range 9 downto 0;
        variable trainingPatternIndex : t_trainingPatternIndex := 5;    
    begin
        
        lvds_data_in    <= (others => trainingPattern_data(trainingPatternIndex));
        lvds_ctrl_in    <= trainingPattern_ctrl(trainingPatternIndex);
        
        -- Provide wrong data to pin to test word alignment error
        if generate_alignment_error then
            lvds_data_in(3) <= '0';
        end if;
        
        -- Select next digit in training pattern
        if(trainingPatternIndex = 9) then
            trainingPatternIndex := 0;
        else
            trainingPatternIndex := trainingPatternIndex + 1;
        end if;
    
    end process generateTrainingPattern;
    
    
    -- Coordinates testing signals
    test : process
    begin
    
        -- Apply reset at startup to give signals initial values
        report "Apply reset at startup to give signals initial values";
        wait until rising_edge(system_clock);
        system_reset <= '1';
        wait until rising_edge(system_clock);
        system_reset <= '0';

        assert pll_locked = '0';
        assert word_alignment_error = '0';
        assert alignment_done = '0';
        
        -- Wait until PLL achieves lock
        report "Wait until PLL achieves lock";
        wait until rising_edge(system_clock) and pll_locked = '1';
        
        assert pll_locked = '1';
        assert word_alignment_error = '0';
        assert alignment_done = '0';

        -- Start alignment
        report "Start alignment";
        cmd_start_align <= '1';
        wait until rising_edge(system_clock);
        cmd_start_align <= '0';

        assert pll_locked = '1';
        assert word_alignment_error = '0';
        assert alignment_done = '0';

        -- Wait for alignment
        report "Wait for alignment";
        wait until rising_edge(system_clock) and (alignment_done = '1' or word_alignment_error = '1');
        wait until rising_edge(system_clock);

        assert pll_locked = '1';
        assert word_alignment_error = '0';
        assert alignment_done = '0';

        -- Turn off clock so PLL loses lock
        report "Turn off clock so PLL loses lock";
        wait until rising_edge(system_clock);
        clock_enable <= '0';
        wait until rising_edge(system_clock) and pll_locked = '0';
        wait until rising_edge(system_clock);
        clock_enable <= '1';
        wait until rising_edge(system_clock) and pll_locked = '1';

        assert pll_locked = '1';
        assert word_alignment_error = '0';
        assert alignment_done = '0';
        
        -- Generate alignment error
        report "Generate alignment error";
        generate_alignment_error <= true;
        wait until rising_edge(lvds_clock_in);
        wait until rising_edge(system_clock);
        cmd_start_align <= '1';
        wait until rising_edge(system_clock);
        cmd_start_align <= '0';
        wait until rising_edge(system_clock) and (alignment_done = '1' or word_alignment_error = '1');
        generate_alignment_error <= false;
        wait until rising_edge(system_clock);

        assert pll_locked = '1';
        assert word_alignment_error = '1';
        assert alignment_done = '0';
        
        -- Reset after receiving word alignment error
        report "Reset after receiving word alignment error";
        system_reset <= '1';
        wait until rising_edge(system_clock);
        system_reset <= '0';

        assert pll_locked = '0';
        assert word_alignment_error = '0';
        assert alignment_done = '0';

        -- Wait until PLL regains lock and restart alignment
        report "Wait until PLL regains lock and restart alignment";
        wait until rising_edge(system_clock) and pll_locked = '1';
        cmd_start_align <= '1';
        wait until rising_edge(system_clock);
        cmd_start_align <= '0';
        wait until rising_edge(system_clock) and (alignment_done = '1' or word_alignment_error = '1');

        assert pll_locked = '1';
        assert word_alignment_error = '0';
        assert alignment_done = '1';

        report "Finished";
        stop;
    end process test;
    
    
    
    dut : lvds_reader_top port map(
        reset_n                 => not system_reset,
        lvds_data_in            => lvds_data_in,
        lvds_ctrl_in            => lvds_ctrl_in,
        lvds_clock_in           => lvds_clock_in,
        alignment_done          => alignment_done,
        cmd_start_align         => cmd_start_align,
        word_alignment_error    => word_alignment_error,
        pll_locked              => pll_locked,
        lvds_parallel_clock     => lvds_parallel_clock,
        lvds_parallel_data      => lvds_parallel_data,
        lvds_parallel_ctrl      => lvds_parallel_ctrl
    );

end tb;