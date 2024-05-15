module SequenceCounter(
    input Clock,
    input Reset,
    input Increment,
    output reg [2:0] SCOut = 3'b000
);
    always@(posedge Clock)
        begin
            if(Reset)
                SCOut <= 0;
            else if(Increment)
                SCOut <= SCOut + 1;
            else
                SCOut <= SCOut;
        end   
endmodule

module Decoder2to8(
    input wire Enable,
    input wire [2:0] TimeDecoderInput,
    output reg [7:0] TimeDecoderOutput
);

    always@(*) begin
        if(Enable) 
        begin
            case(TimeDecoderInput)
                3'b000 : TimeDecoderOutput = 8'b00000001;   // T0 
                3'b001 : TimeDecoderOutput = 8'b00000010;   // T1
                3'b010 : TimeDecoderOutput = 8'b00000100;   // T2
                3'b011 : TimeDecoderOutput = 8'b00001000;   // T3
                3'b100 : TimeDecoderOutput = 8'b00010000;   // T4
                3'b101 : TimeDecoderOutput = 8'b00100000;   // T5
                3'b110 : TimeDecoderOutput = 8'b01000000;   // T6
                3'b111 : TimeDecoderOutput = 8'b10000000;   // T7
                default: TimeDecoderOutput = 8'b00000000;   // T0
            endcase    
        end 
        else
        begin
            TimeDecoderOutput = TimeDecoderOutput;    
        end
    end  
endmodule

module CPUSystem(
    input Clock,
    input Reset,
    output wire [7:0] T
);  
    reg  IR_LH, IR_Write, Mem_CS, Mem_WR, ALU_WF, MuxCSel, SCReset, IncrementSC;
    reg [1:0] ARF_OutCSel, ARF_OutDSel, MuxASel, MuxBSel, Rsel, cont = 0; 
    reg [2:0] RF_OutASel, RF_OutBSel, RF_FunSel, ARF_FunSel;
    reg [2:0] ARF_RegSel;
    reg [3:0] RF_RegSel;
    reg [3:0] RF_ScrSel; 
    reg [3:0] RF_ScrSel_Extra;
    reg [4:0] ALU_FunSel;
    reg [5:0] OpCode;
    reg  [15:0] temp;
    wire [2:0] TimeDecoderInput;
    wire [3:0] ALUOutFlag;
    wire [7:0] MemOut;
    wire [15:0] Address, IROut, ALUOut, MuxAOut, OutA, OutB, OutC;
    wire S;
    
   ArithmeticLogicUnitSystem _ALUSystem(.Clock(Clock), .RF_OutASel(RF_OutASel), .RF_OutBSel(RF_OutBSel), .RF_FunSel(RF_FunSel), .RF_RegSel(RF_RegSel),
                              .RF_ScrSel(RF_ScrSel), .ALU_FunSel(ALU_FunSel), .ALUOut(ALUOut), .ARF_OutCSel(ARF_OutCSel), .ARF_OutDSel(ARF_OutDSel), .ARF_FunSel(ARF_FunSel),
                              .ARF_RegSel(ARF_RegSel), .IROut(IROut), .IR_LH(IR_LH), .IR_Write(IR_Write), .Mem_CS(Mem_CS), .Mem_WR(Mem_WR),.MemOut(MemOut), .ALU_WF(ALU_WF), .MuxASel(MuxASel),
                              .MuxBSel(MuxBSel), .MuxCSel(MuxCSel), .Address(Address), .MuxAOut(MuxAOut), .OutA(OutA), .OutB(OutB), .OutC(OutC), .ALUOutFlag(ALUOutFlag));
                              
   SequenceCounter SC(Clock, SCReset, IncrementSC, TimeDecoderInput);
   Decoder2to8 TimeDecoder(1'b1,TimeDecoderInput, T);

 
    always @(*) begin
        if (Reset) begin
            SCReset = 1;
            //ARF_FunSel = 3'b000; niye var bilmiyorum
        end
        if (!Reset) begin
            cont = 0;
            SCReset = 0;
            IncrementSC = 1; // Sequence counter'� 1 art�r
            //$display("T: %d", T);
            case(T)
                1: begin  //IR'nin ilk 8 biti y�kleniyor.       // T = 0
                    //$display("T[0]");
                    IR_Write = 1; // Insruction register'� enable ediyorum.
                    IR_LH = 1'b0; // ilk 8 biti y�kle
                    Mem_WR = 1'b0; // Memory'nin read modunu a�
                    Mem_CS = 1'b0; // Memory'yi enable et
                    ARF_OutDSel = 2'b00; // Memory'nin address k�sm�na giden outu i�in PC'yi se�
                    ARF_RegSel = 3'b011; // PC register� enable et
                    ARF_FunSel = 3'b001; // Pc registeri 1 art�r 
                    //$display("Address: %h", Address);
                    //$display("MemOut: %h", MemOut);
                    //$display("IROut[7:0]: %h", IROut[7:0]);
                    //$display("IROut[15:8]: %h", IROut[15:8]);
                end
                2: begin //IR'nin son 8 biti y�kleniyor.        // T = 1      
                    //$display("T[1]");
                    IR_LH = 1'b1; // son 8 biti y�kle                      
                    //$display("Address: %h", Address);
                    //$display("MemOut: %h", MemOut);
                    //$display("IROut[7:0]: %h", IROut[7:0]);
                    //$display("IROut[15:8]: %h", IROut[15:8]);
                    OpCode = IROut[15:10];
                end  
                
                // OPCODE (6-bit) + RSEL (2-bit) + ADDRESS (8-bit)
                // OPCODE (6-bit) + S (1-bit) + DSTREG (3-bit) + SREG1 (3-bit) + SREG2 (3-bit)

                4: begin // Fetch i�lemi bitti. //Decode i�lemi de yap�lm�� oldu bu a�amada. // T = 2
                    ARF_RegSel = 3'b111; // PC register� disable et, artmamas� gerekiyor.
                    MuxBSel = 2'b00; // ARF'e aluout giri� yap�yor.
                    //$display("T[2]");
                    Rsel = IROut[9:8]; // Rsel'i al.
                    IR_Write = 0; // Instruction register'i kapat.
                    Mem_CS = 1'b1; // Memory'yi disable et
                    
                    case (OpCode)
                        6'b000000: begin // BRA PC <- PC + VALUE
                            MuxASel = 2'b11;
                            //$display("Rsel: %h", Rsel);
                            case (Rsel)
                                2'b00: begin // S1 and S2 is enabled.
                                    RF_ScrSel = 4'b0111;
                                    RF_OutASel = 3'b100;
                                    RF_ScrSel_Extra = 4'b1011;
                                    RF_OutBSel = 3'b101;
                                end
                                2'b01: begin // S2 and S1 is enabled.
                                    RF_ScrSel = 4'b1011;
                                    RF_OutASel = 3'b101;
                                    RF_ScrSel_Extra = 4'b0111;
                                    RF_OutBSel = 3'b100;
                                end
                                2'b10: begin // S3 and S1 is enabled.
                                    RF_ScrSel = 4'b1101;
                                    RF_OutASel = 3'b110;
                                    RF_ScrSel_Extra = 4'b0111;
                                    RF_OutBSel = 3'b100;
                                end
                                2'b11: begin // S4 and S1 is enabled.
                                    RF_ScrSel = 4'b1110;
                                    RF_OutASel = 3'b111;
                                    RF_ScrSel_Extra = 4'b0111;
                                    RF_OutBSel = 3'b100;
                                end                             
                            endcase
                            RF_FunSel = 3'b010; // Q = I    // S1 is loading.
                            ALU_FunSel = 5'b10101; // A + B + carry 16 bit
                            //$display("MuxAOut: %h", MuxAOut);
                            //$display("OutA: %h", OutA);
                            //$display("OutB: %h", OutB);
                            //$display("Aluout: %h", ALUOut);
                            //$display("RF_ScrSel: %h", RF_ScrSel);  
                            //$display("RF_FunSel: %h", RF_FunSel);   
                            //$display("ALU_FunSel: %h", ALU_FunSel); 
                        end
                        6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            if(_ALUSystem.ALUOutFlag[3] == 0)begin
                                cont = 1;
                                MuxASel = 2'b11;
                                //$display("Rsel: %h", Rsel);
                                case (Rsel)
                                    2'b00: begin // S1 and S2 is enabled.
                                        RF_ScrSel = 4'b0111;
                                        RF_OutASel = 3'b100;
                                        RF_ScrSel_Extra = 4'b1011;
                                        RF_OutBSel = 3'b101;
                                    end
                                    2'b01: begin // S2 and S1 is enabled.
                                        RF_ScrSel = 4'b1011;
                                        RF_OutASel = 3'b101;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end
                                    2'b10: begin // S3 and S1 is enabled.
                                        RF_ScrSel = 4'b1101;
                                        RF_OutASel = 3'b110;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end
                                    2'b11: begin // S4 and S1 is enabled.
                                        RF_ScrSel = 4'b1110;
                                        RF_OutASel = 3'b111;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end                             
                                endcase
                                RF_FunSel = 3'b010; // Q = I    // S1 is loading.
                                ALU_FunSel = 5'b10101; // A + B + carry 16 bit
                                //$display("MuxAOut: %h", MuxAOut);
                                //$display("OutA: %h", OutA);
                                //$display("OutB: %h", OutB);
                                //$display("Aluout: %h", ALUOut);
                                //$display("RF_ScrSel: %h", RF_ScrSel);  
                                //$display("RF_FunSel: %h", RF_FunSel);   
                                //$display("ALU_FunSel: %h", ALU_FunSel); 
                            end
                        end
                        6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            if(_ALUSystem.ALUOutFlag[3] == 1)begin
                                cont = 1;
                                MuxASel = 2'b11;
                                //$display("Rsel: %h", Rsel);
                                case (Rsel)
                                    2'b00: begin // S1 and S2 is enabled.
                                        RF_ScrSel = 4'b0111;
                                        RF_OutASel = 3'b100;
                                        RF_ScrSel_Extra = 4'b1011;
                                        RF_OutBSel = 3'b101;
                                    end
                                    2'b01: begin // S2 and S1 is enabled.
                                        RF_ScrSel = 4'b1011;
                                        RF_OutASel = 3'b101;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end
                                    2'b10: begin // S3 and S1 is enabled.
                                        RF_ScrSel = 4'b1101;
                                        RF_OutASel = 3'b110;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end
                                    2'b11: begin // S4 and S1 is enabled.
                                        RF_ScrSel = 4'b1110;
                                        RF_OutASel = 3'b111;
                                        RF_ScrSel_Extra = 4'b0111;
                                        RF_OutBSel = 3'b100;
                                    end                             
                                endcase
                                RF_FunSel = 3'b010; // Q = I    // S1 is loading.
                                ALU_FunSel = 5'b10101; // A + B + carry 16 bit
                                //$display("MuxAOut: %h", MuxAOut);
                                //$display("OutA: %h", OutA);
                                //$display("OutB: %h", OutB);
                                //$display("Aluout: %h", ALUOut);
                                //$display("RF_ScrSel: %h", RF_ScrSel);  
                                //$display("RF_FunSel: %h", RF_FunSel);   
                                //$display("ALU_FunSel: %h", ALU_FunSel); 
                            end
                        end
                        6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                        end
                        6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                        end
                        6'b000101: begin // INC DSTREG ? SREG1 + 1
                        end
                        6'b000110: begin // DEC DSTREG ? SREG1 - 1
                        end
                        6'b000111: begin // LSL DSTREG ? LSL SREG1
                        end
                        6'b001000: begin // LSR DSTREG ? LSR SREG1
                        end
                        6'b001001: begin // ASR DSTREG ? ASR SREG1
                        end
                        6'b001010: begin // CSL DSTREG ? CSL SREG1
                        end
                        6'b001011: begin // CSR DSTREG ? CSR SREG1  
                        end
                        6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                        end
                        6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                        end
                        6'b001110: begin // NOT DSTREG ? NOT SREG1
                        end
                        6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                        end
                        6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                        end
                        6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                        end
                        6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                        end
                        6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                        end
                        6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                        end
                        6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                        end
                        6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                        end
                        6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                        end
                        6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                        end
                        6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                        end
                        6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                        end
                        6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                        end
                        6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                        end
                        6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                        end
                        6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                        end
                        6'b011111: begin // BL PC ? M[SP]
                        end
                        6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                        end
                        6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                        end                        
                    endcase                      
                end
                
                8: begin // EXECUTE  T = 3                    
                    case (OpCode)
                        6'b000000: begin // BRA PC <- PC + VALUE                        
                            ARF_OutCSel = 2'b00; // PC'y� ARF'nin ��k���na veriyor.
                            MuxASel = 2'b01; // RF input is changing.
                            RF_ScrSel = RF_ScrSel_Extra;  //S2'ye PC y�kleniyor.                            
                            //$display("MuxAOut: %d", MuxAOut);
                            //$display("OutA: %d", OutA);
                            //$display("OutB: %d", OutB);
                            //$display("Aluout: %d", ALUOut);         
                        end
                        6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            if(cont == 1)begin
                                ARF_OutCSel = 2'b00; // PC'y� ARF'nin ��k���na veriyor.
                                MuxASel = 2'b01; // RF input is changing.
                                RF_ScrSel = RF_ScrSel_Extra;  //S2'ye PC y�kleniyor.                            
                                //$display("MuxAOut: %d", MuxAOut);
                                //$display("OutA: %d", OutA);
                                //$display("OutB: %d", OutB);
                                //$display("Aluout: %d", ALUOut);    
                            end
                        end
                        6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            if(cont == 1)begin
                                ARF_OutCSel = 2'b00; // PC'y� ARF'nin ��k���na veriyor.
                                MuxASel = 2'b01; // RF input is changing.
                                RF_ScrSel = RF_ScrSel_Extra;  //S2'ye PC y�kleniyor.                            
                                //$display("MuxAOut: %d", MuxAOut);
                                //$display("OutA: %d", OutA);
                                //$display("OutB: %d", OutB);
                                //$display("Aluout: %d", ALUOut);    
                            end    
                        end
                        6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                        end
                        6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                        end
                        6'b000101: begin // INC DSTREG ? SREG1 + 1
                        end
                        6'b000110: begin // DEC DSTREG ? SREG1 - 1
                        end
                        6'b000111: begin // LSL DSTREG ? LSL SREG1
                        end
                        6'b001000: begin // LSR DSTREG ? LSR SREG1
                        end
                        6'b001001: begin // ASR DSTREG ? ASR SREG1
                        end
                        6'b001010: begin // CSL DSTREG ? CSL SREG1
                        end
                        6'b001011: begin // CSR DSTREG ? CSR SREG1  
                        end
                        6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                        end
                        6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                        end
                        6'b001110: begin // NOT DSTREG ? NOT SREG1
                        end
                        6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                        end
                        6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                        end
                        6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                        end
                        6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                        end
                        6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                        end
                        6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                        end
                        6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                        end
                        6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                        end
                        6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                        end
                        6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                        end
                        6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                        end
                        6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                        end
                        6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                        end
                        6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                        end
                        6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                        end
                        6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                        end
                        6'b011111: begin // BL PC ? M[SP]
                        end
                        6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                        end
                        6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                        end                        
                    endcase    
                end
                16: begin // EXECUTE T = 4
                    case (OpCode)
                        6'b000000: begin // BRA PC ? PC + VALUE
                            ARF_FunSel = 3'b010; // PC registar'a y�kleme yap. 
                            ARF_RegSel = 3'b011; // PC register� disable et, artmamas� gerekiyor.                             
                            //$display("Aluout: %d", ALUOut);
                            //$display("PC: %d", _ALUSystem.ARF.PC.Q);
                            SCReset = 1;

                        end
                        6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            if(cont == 1)begin
                                ARF_FunSel = 3'b010; // PC registar'a y�kleme yap. 
                                ARF_RegSel = 3'b011; // PC register� disable et, artmamas� gerekiyor.                             
                                //$display("Aluout: %d", ALUOut);
                                //$display("PC: %d", _ALUSystem.ARF.PC.Q);
                                SCReset = 1;                            
                            end
                        end
                        6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            if(cont == 1)begin
                                ARF_FunSel = 3'b010; // PC registar'a y�kleme yap. 
                                ARF_RegSel = 3'b011; // PC register� disable et, artmamas� gerekiyor.                             
                                //$display("Aluout: %d", ALUOut);
                                //$display("PC: %d", _ALUSystem.ARF.PC.Q);
                                SCReset = 1;                            
                            end
                        end
                        6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                        end
                        6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                        end
                        6'b000101: begin // INC DSTREG ? SREG1 + 1
                        end
                        6'b000110: begin // DEC DSTREG ? SREG1 - 1
                        end
                        6'b000111: begin // LSL DSTREG ? LSL SREG1
                        end
                        6'b001000: begin // LSR DSTREG ? LSR SREG1
                        end
                        6'b001001: begin // ASR DSTREG ? ASR SREG1
                        end
                        6'b001010: begin // CSL DSTREG ? CSL SREG1
                        end
                        6'b001011: begin // CSR DSTREG ? CSR SREG1  
                        end
                        6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                        end
                        6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                        end
                        6'b001110: begin // NOT DSTREG ? NOT SREG1
                        end
                        6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                        end
                        6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                        end
                        6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                        end
                        6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                        end
                        6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                        end
                        6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                        end
                        6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                        end
                        6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                        end
                        6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                        end
                        6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                        end
                        6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                        end
                        6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                        end
                        6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                        end
                        6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                        end
                        6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                        end
                        6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                        end
                        6'b011111: begin // BL PC ? M[SP]
                        end
                        6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                        end
                        6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                        end                        
                    endcase    
                end
                32: begin // EXECUTE T = 5
                        case (OpCode)
                            6'b000000: begin // BRA PC ? PC + VALUE
                            end
                            6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            end
                            6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            end
                            6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                            end
                            6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                            end
                            6'b000101: begin // INC DSTREG ? SREG1 + 1
                            end
                            6'b000110: begin // DEC DSTREG ? SREG1 - 1
                            end
                            6'b000111: begin // LSL DSTREG ? LSL SREG1
                            end
                            6'b001000: begin // LSR DSTREG ? LSR SREG1
                            end
                            6'b001001: begin // ASR DSTREG ? ASR SREG1
                            end
                            6'b001010: begin // CSL DSTREG ? CSL SREG1
                            end
                            6'b001011: begin // CSR DSTREG ? CSR SREG1  
                            end
                            6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                            end
                            6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                            end
                            6'b001110: begin // NOT DSTREG ? NOT SREG1
                            end
                            6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                            end
                            6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                            end
                            6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                            end
                            6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                            end
                            6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                            end
                            6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                            end
                            6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                            end
                            6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                            end
                            6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                            end
                            6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                            end
                            6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                            end
                            6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                            end
                            6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                            end
                            6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                            end
                            6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                            end
                            6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                            end
                            6'b011111: begin // BL PC ? M[SP]
                            end
                            6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                            end
                            6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                            end                        
                    endcase
                end                
                64: begin // EXECUTE T = 6
                        case (OpCode)
                            6'b000000: begin // BRA PC ? PC + VALUE
                            end
                            6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            end
                            6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            end
                            6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                            end
                            6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                            end
                            6'b000101: begin // INC DSTREG ? SREG1 + 1
                            end
                            6'b000110: begin // DEC DSTREG ? SREG1 - 1
                            end
                            6'b000111: begin // LSL DSTREG ? LSL SREG1
                            end
                            6'b001000: begin // LSR DSTREG ? LSR SREG1
                            end
                            6'b001001: begin // ASR DSTREG ? ASR SREG1
                            end
                            6'b001010: begin // CSL DSTREG ? CSL SREG1
                            end
                            6'b001011: begin // CSR DSTREG ? CSR SREG1  
                            end
                            6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                            end
                            6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                            end
                            6'b001110: begin // NOT DSTREG ? NOT SREG1
                            end
                            6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                            end
                            6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                            end
                            6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                            end
                            6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                            end
                            6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                            end
                            6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                            end
                            6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                            end
                            6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                            end
                            6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                            end
                            6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                            end
                            6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                            end
                            6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                            end
                            6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                            end
                            6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                            end
                            6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                            end
                            6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                            end
                            6'b011111: begin // BL PC ? M[SP]
                            end
                            6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                            end
                            6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                            end                        
                    endcase
                end
                128:begin // EXECUTE T = 7
                        case (OpCode)
                            6'b000000: begin // BRA PC ? PC + VALUE
                            end
                            6'b000001: begin // BNE IF Z=0 THEN PC ? PC + VALUE 
                            end
                            6'b000010: begin // BEQ IF Z=1 THEN PC ? PC + VALUE
                            end
                            6'b000011: begin // POP SP ? SP + 1, Rx ? M[SP]
                            end
                            6'b000100: begin // PSH M[SP] ? Rx, SP ? SP - 1
                            end
                            6'b000101: begin // INC DSTREG ? SREG1 + 1
                            end
                            6'b000110: begin // DEC DSTREG ? SREG1 - 1
                            end
                            6'b000111: begin // LSL DSTREG ? LSL SREG1
                            end
                            6'b001000: begin // LSR DSTREG ? LSR SREG1
                            end
                            6'b001001: begin // ASR DSTREG ? ASR SREG1
                            end
                            6'b001010: begin // CSL DSTREG ? CSL SREG1
                            end
                            6'b001011: begin // CSR DSTREG ? CSR SREG1  
                            end
                            6'b001100: begin // AND DSTREG ? SREG1 AND SREG2
                            end
                            6'b001101: begin // ORR DSTREG ? SREG1 OR SREG2
                            end
                            6'b001110: begin // NOT DSTREG ? NOT SREG1
                            end
                            6'b001111: begin // XOR DSTREG ? SREG1 XOR SREG2
                            end
                            6'b010000: begin // NAND DSTREG ? SREG1 NAND SREG2
                            end
                            6'b010001: begin // MOVH DSTREG[15:8] ? IMMEDIATE (8-bit)
                            end
                            6'b010010: begin // LDR (16-bit) Rx ? M[AR] (AR is 16-bit register)  
                            end
                            6'b010011: begin // STR (16-bit) M[AR] ? Rx (AR is 16-bit register)
                            end
                            6'b010100: begin // MOVL DSTREG[7:0] ?  IMMEDIATE (8-bit)
                            end
                            6'b010101: begin // ADD DSTREG ? SREG1 + SREG2
                            end
                            6'b010110: begin // ADC DSTREG ? SREG1 + SREG2 + CARRY
                            end
                            6'b010111: begin // SUB DSTREG ? SREG1 - SREG2
                            end
                            6'b011000: begin // MOVS DSTREG ? SREG1, Flags will change
                            end
                            6'b011001: begin // ADDS DSTREG ? SREG1 + SREG2, Flags will change
                            end
                            6'b011010: begin // SUBS DSTREG ? SREG1 - SREG2, Flags will change
                            end
                            6'b011011: begin // ANDS DSTREG ? SREG1 AND SREG2, Flags will change
                            end
                            6'b011100: begin // ORRS DSTREG ? SREG1 OR SREG2, Flags will change
                            end
                            6'b011101: begin // XORS DSTREG ? SREG1 XOR SREG2, Flags will change
                            end
                            6'b011110: begin // BX M[SP] ? PC, PC ? Rx 
                            end
                            6'b011111: begin // BL PC ? M[SP]
                            end
                            6'b100000: begin // LDRIM Rx ? VALUE (VALUE defined in ADDRESS bits)
                            end
                            6'b100001: begin // STRIM M[AR+OFFSET] ? Rx (AR is 16-bit register) (OFFSET defined in ADDRESS bits)
                            end                        
                    endcase
                end
            endcase
        end
    end                                       
endmodule
