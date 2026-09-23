IVERILOG = iverilog
VVP = vvp
IFLAGS = -Wall -g2012 -I../src
SRC = ../src

.PHONY: all clean alu math timer cpu

all: alu math timer cpu

alu: tb_alu.vvp
	$(VVP) $<

math: tb_math_unit.vvp
	$(VVP) $<

timer: tb_timer.vvp
	$(VVP) $<

cpu: tb_cpu_core.vvp
	$(VVP) $<

tb_alu.vvp: tb_alu.v $(SRC)/alu.v $(SRC)/cpu_defines.vh
	$(IVERILOG) $(IFLAGS) -o $@ tb_alu.v $(SRC)/alu.v

tb_math_unit.vvp: tb_math_unit.v $(SRC)/math_unit.v $(SRC)/cpu_defines.vh
	$(IVERILOG) $(IFLAGS) -o $@ tb_math_unit.v $(SRC)/math_unit.v

tb_timer.vvp: tb_timer.v $(SRC)/timer.v $(SRC)/cpu_defines.vh
	$(IVERILOG) $(IFLAGS) -o $@ tb_timer.v $(SRC)/timer.v

tb_cpu_core.vvp: tb_cpu_core.v $(SRC)/cpu_core.v $(SRC)/control_unit.v \
                 $(SRC)/register_file.v $(SRC)/alu.v $(SRC)/address_gen.v \
                 $(SRC)/cpu_defines.vh
	$(IVERILOG) $(IFLAGS) -o $@ tb_cpu_core.v $(SRC)/cpu_core.v \
		$(SRC)/control_unit.v $(SRC)/register_file.v $(SRC)/alu.v \
		$(SRC)/address_gen.v

clean:
	rm -f *.vvp *.vcd
