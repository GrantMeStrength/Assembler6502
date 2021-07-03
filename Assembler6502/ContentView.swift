//
//  ContentView.swift
//  Assembler6502
//
//  Created by John Kennedy on 7/1/21.
//

import SwiftUI



struct ContentView: View {
    
    @State private var sourceCode: String = "org $200\nstart:\nADC #52; this is a comment\nbra end\nbra start\nlda end\nORA #$12\nAND $12,x\nSBC $1234\nADC $1234,x\nADC $1234,Y\nNOP\nnop; more comments\n\nlda    $12\nrts\nend:"
    
    @State private var objectCodeText: String = "Assembled code appears here"
    
    @State private var SourceCodeVisibility = 1.0
    
    
    var body: some View {
        
        
        
        ZStack {
            
            VStack {
                TextEditor(text: $sourceCode)
                    .padding()
                    .font(.custom("Menlo", size: 13))
                
                Button("Assemble", action:
                        { assemble(source : sourceCode); SourceCodeVisibility = 0.0 }
                ).padding()
                
            }.opacity(SourceCodeVisibility)
            
           
            
            VStack {
                TextEditor(text: $objectCodeText)
                    .padding()
                    .font(.custom("Menlo", size: 13))
                
                Button("Back to editor", action:
                        { SourceCodeVisibility = 1.0 }
                ).padding()
                
                
                
            }.opacity(1 - SourceCodeVisibility)
            
            
            
        }
    }
    
    private func DisplayObjectCode(text : String)
    {
        objectCodeText = objectCodeText + text
    }
    
    private func assemble(source : String)
    {

         
        let SingleByteInstructions : [String : UInt] = ["BRK" : 0x00, "PHP" : 0x08,   "CLC" : 0x18,  "INCA" : 0x18, "PLP" : 0x28,  "SEC" : 0x38,  "DECA" : 0x38, "RTI" : 0x40,  "PHA" : 0x48,  "CLI" : 0x58,  "PHY" : 0x5A, "RTS" : 0x60, "PLA" : 0x68, "SEI" : 0x78, "PLY" : 0x7a, "DEY" : 0x88, "TXA" : 0x8A, "TYA" : 0x98, "TXS" : 0x9A, "TAY" : 0xA8, "TAX" : 0xAA, "CLV" : 0xB8, "TSX" : 0xBA, "INY" : 0xC8, "DEX" : 0xCA,  "CLD" : 0xD8, "PHX" : 0xDA, "INX" : 0xE8,  "NOP" : 0xEA, "SED" : 0xF8, "PLX" : 0xFA]
        
        let BranchInstructions : [String : UInt] = ["BCC" : 0x90, "BCS" : 0xb0, "BEQ" : 0xf0, "BMI" : 0x30, "BPL" : 0x10, "BNE" : 0xD0, "BRA" : 0x80, "BVC" : 0x50, "BVS" : 0x70];
        
        
        var PC : UInt16 = 0
        var symbolTable: [String: UInt16] = [:]
        
           
        /// Zero pass - remove comments
        var newSourceCode = ""
        
        let sourceCodeLines = source.components(separatedBy: "\n")
        
        for line in sourceCodeLines
        {
            if line != ""
            {
                if line.contains(";")
                {
                    let s = line.components(separatedBy: ";")
                    newSourceCode = newSourceCode + s[0] + "\n"
                }
                else
                {
                    newSourceCode = newSourceCode + line + "\n"
                }
            }
        }
        
        /// Upcase it and Replace smartquotes
        
        newSourceCode =  newSourceCode.uppercased()
        newSourceCode = newSourceCode.replacingOccurrences(of: "“", with: "\"")
        newSourceCode = newSourceCode.replacingOccurrences(of: "”", with: "\"")
        
       
        
        /// Split up into individual tokens now for processing - tokens is the array that contains the source code now
        /// and we will only use it from now on.
        
        var tokens = newSourceCode.uppercased().condensed.components(separatedBy: NSCharacterSet.whitespacesAndNewlines)
        
        var PASS = 1
        
        while PASS < 3
        {
            PC = 0
            
            objectCodeText = "--- Assembly output ---\n\n"
            
            var NumberOfBytes : UInt16 = 0 // Kept track of instructions for pretty output
            
            var index = 0
            while index < tokens.count
            {
                let word = tokens[index]
                index = index + 1
                
                // Display the current PC
                
                if PASS == 2
                {
                DisplayObjectCode(text: String(format: "%04X",PC) + "\t")
                }
                
                NumberOfBytes = 0 /// Keep track of single byte instructions, but just for prettyfiying display
                
                /// Add a Label to the reference table - MUST end with a :
                if word.hasSuffix(":")
                {
                    NumberOfBytes = 1
                   symbolTable.updateValue(PC, forKey: word.replacingOccurrences(of: ":", with: ""))
                }
                else
                    /// Org
                    if word == "ORG" {
                        NumberOfBytes = 1
                        PC = ORG(address:tokens[index] )
                        index = index + 1
                    }
                else
                    /// Equ
                    if word == "EQU" && PASS == 1 { /// do not add a : to a symbol in this situation
                        NumberOfBytes = 1
                        symbolTable.updateValue(EQU(address:tokens[index]), forKey: tokens[index-2])
                        index = index + 1
                    }
                else
                    /// DB
                    if word == "DB" {
                        NumberOfBytes = 1
                        
                        let quotes = tokens[index].filter { $0 == "\"" }.count
                        var foundendquote = false
                        
                        if quotes == 1 /// Tricky case as words separate by spaces will be in different tokens
                        {
                            
                            var textblock = tokens[index]
                            
                            while !foundendquote || index >= tokens.count
                            {
                                
                                index = index + 1
                                textblock = textblock + " " + tokens[index]
                                if tokens[index].contains("\"")
                                {
                                    foundendquote = true
                                }
                            }
                            
                            PC = PC + DB(data:textblock )
                            
                        }
                        else
                        {
                            PC = PC + DB(data:tokens[index] )
                        }
                        
                        index = index + 1
                    }
                else
                    /// Single byte instructions
                    if let ins = SingleByteInstructions[word]
                {
                        NumberOfBytes = 1
                        AddInstruction(UInt8(ins));
                        PC = PC + 1
                    }
                else
                    /// Branch instructions - these are a little fiddly as normally 16 bit labels will actually be dealt with as 8 bit relative values.
                    if let ins = BranchInstructions[word]
                {
                        AddInstruction(UInt8(ins));
                        
                        if PASS == 1
                        {
                            
                            _ = Branch(param:  tokens[index], currentPC: PC)
                        }
                        else
                        {
                            tokens[index] = "$"+String(format: "%02X",Branch(param:  tokens[index], currentPC: PC)) // Store the address purely for the display
                            
                        }
                        
                        index = index + 1
                        PC = PC + 2
                        NumberOfBytes = 2
                    }
                
                else
                    if word == "ORA" {
                        NumberOfBytes = InstructionSet(offset: 0x00, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "AND" {
                        NumberOfBytes =  InstructionSet(offset: 0x20, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "EOR" {
                        NumberOfBytes = InstructionSet(offset: 0x40, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "ADC" {
                        NumberOfBytes = InstructionSet(offset: 0x60, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "STA" {
                        NumberOfBytes = InstructionSet(offset: 0x80, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "LDA" {
                        NumberOfBytes = InstructionSet(offset: 0xA0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "CMP" {
                        NumberOfBytes = InstructionSet(offset: 0xC0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "SBC" {
                        NumberOfBytes = InstructionSet(offset: 0xE0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "ASL" {
                        NumberOfBytes = SHIFTandROTATES(offset: 0, param: tokens[index])
                        index = index + 1
                    }
                else
                    if word == "ROL" {
                        NumberOfBytes = SHIFTandROTATES(offset: 20, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "ROR" {
                        NumberOfBytes = SHIFTandROTATES(offset: 60, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "LSR" {
                        NumberOfBytes = SHIFTandROTATES(offset: 40, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "BIT" {
                        NumberOfBytes = BIT(param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                
                else
                    if word == "CPY" {
                        NumberOfBytes =  CPXCPY(offset: 0xC0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "CPX" {
                        NumberOfBytes =  CPXCPY(offset: 0xE0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "DEC" {
                        NumberOfBytes = INCDEC(offset: 0xC0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "INC" {
                        NumberOfBytes = INCDEC(offset: 0xE0, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "JSR" {
                        NumberOfBytes = JumpSubroutine(param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "JMP" {
                        NumberOfBytes = Jump(param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else //TESTBITS
                    if word == "TRB" {
                        NumberOfBytes =  TESTBITS(offset: 0x10, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                else
                    if word == "TSB" {
                        NumberOfBytes =  TESTBITS(offset: 0x00, param: tokens[index])
                        PC = PC + NumberOfBytes
                        index = index + 1
                    }
                
                /// Display the mnemonics
                
                switch (NumberOfBytes) {
                    
                case 1:  DisplayObjectCode(text: "\t\t\t" + word + "\n")
                case 2:  DisplayObjectCode(text: "\t\t" + word + "  " + tokens[index-1] + "\n")
                case 3:  DisplayObjectCode(text: "\t" + word + "  " + tokens[index-1] + "\n")
                default: DisplayObjectCode(text: "\t" + word + "  " + tokens[index-1] + "\n")
                    
                }
                
               
            }
            
            if PASS == 1
            {
                /// Now search and replace labels and rinse and repeat
                
                for (index, token) in tokens.enumerated()
                {
                    for label in symbolTable {
                        
                        if token == label.key
                        {
                            tokens[index] =  "$"+String(format: "%04X",label.value)
                        }
                    }
                }
                

                
            }
            
            if PASS == 2
            {
                
                
                
                
                /// Now search and replace symbols and do it all again
                
                DisplayObjectCode(text: "\n\n --- Symbol table --- \n\n")
                for label in symbolTable
                {
                    DisplayObjectCode(text: String(format: "%04X",label.value) + " = " + label.key  +  "\n")
                }
                
               
            }
            
            PASS = PASS + 1
            
        }
    }
    
    func GetNumber(input : String) -> UInt8?
    {
        var base = 10
        var n = input
        
        if input.starts(with: "$")
        {
            base = 16
            n = input.replacingOccurrences(of: "$", with: "")
        }
        
        if input.starts(with: "%")
        {
            base = 2
            n = input.replacingOccurrences(of: "%", with: "")
        }
        
        return UInt8(n, radix: base)
        
    }
    
    func GetAddress(input : String) -> UInt16?
    {
        var base = 10
        var n = input
        
        if input.starts(with: "$")
        {
            base = 16
            n = input.replacingOccurrences(of: "$", with: "")
            
        }
        
        if input.starts(with: "%")
        {
            base = 2
            n = input.replacingOccurrences(of: "%", with: "")
        }
        
        return UInt16(n, radix: base)
        
    }
    
    enum AddressingModes {
        case Immediate
        case ZeroPage
        case ZeroPageX
        case Absolute
        case AbsoluteX
        case AbsoluteY
        case IndirectX
        case IndirectY
        case Indirect
        case Error
    }
    
    private func perror(error : String)
    {
        DisplayObjectCode(text: "\nError: " + error + "\n")
    }
    
    /// Actually output the hex for the instruction
    private func AddInstruction(_ thecode: UInt8)
    {
        DisplayObjectCode(text: String(format: "%02X",thecode))
    }
    /// Actually output the hex for the params or data
    private func AddByte(_ thebyte: UInt8)
    {
        DisplayObjectCode(text: String(format: " %02X",thebyte))
    }
    
    private func AddWord(_ theword: UInt16)
    {
        
        let lsb = UInt8( theword & 0x00FF)
        let msb = UInt8( theword >> 8)
        AddByte(lsb)
        AddByte(msb)
        
    }
    
    
    private func Branch(param : String,  currentPC : UInt16) -> UInt8
    {
        let rel = GetAddress(input: param) /// Might be a label!
        
        if param.count == 5 && rel != nil /// Horrible special case to detect that a label has been expanded here
        {
            var r = Int16(rel!) - Int16(currentPC) - 2
            if r < 0 {r = r + 256}
            r = r & 255
            AddByte(UInt8(r))
            return UInt8(r)
        }
        
        if rel != nil
        {
            let r = UInt8(rel!)
            AddByte(r)
            return UInt8(r)
        }
        else
        {
            /// Look up in table later
            AddByte(0)
            return 0
            
        }
        
        
    }
    
    private func Jump(param : String) -> UInt16
    {
        let r = GetAddresingMode(token: param)
        if r.mode == .Error
        {
            AddInstruction(0x6C); AddByte(0); AddByte(0);
        }
        
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .Indirect :  AddInstruction(0x6C); AddByte(lsb); AddByte(msb);
        case .Absolute :  AddInstruction(0x4C); AddByte(lsb); AddByte(msb);
            
        case .Error : perror(error: param);
        default: perror(error: param);
        }
        
        return 3
    }
    
    
    private func JumpSubroutine(param : String) -> UInt16
    {
        let rel = GetAddress(input: param) // Might be a label!
        if rel != nil
        {
            AddInstruction(0x20)
            AddWord(rel!)
            
        }
        else
        {
            // Look up in table
            AddInstruction(0x20)
            AddWord(0)
            
        }
        
        return 3
    }
    
    private func InstructionSet(offset : UInt8, param : String) -> UInt16
    {
        /// Used by many different instructions - the ones that are predictably numbered  anyway
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .Immediate : AddInstruction(offset + 9); AddByte(lsb); return 2
        case .ZeroPage :  AddInstruction(offset + 5); AddByte(lsb); return 2
        case .ZeroPageX : AddInstruction(offset + 0x15); AddByte(lsb); return 2
        case .IndirectX : AddInstruction(offset + 1); AddByte(lsb); return 2
        case .IndirectY : AddInstruction(offset + 0x11); AddByte(lsb); return 2
        case .Indirect :  AddInstruction(offset + 0x12); AddByte(lsb); return 2
        case .Absolute :  AddInstruction(offset + 0x0D); AddByte(lsb); AddByte(msb); return 3
        case .AbsoluteX : AddInstruction(offset + 0x1D); AddByte(lsb); AddByte(msb); return 3
        case .AbsoluteY : AddInstruction(offset + 0x19); AddByte(lsb); AddByte(msb); return 3
        case .Error : perror( error: "Unable to determine address mode or value " + param);return 3 // assuming this is a label
        }
    }
    
    
    private func SHIFTandROTATES(offset : UInt8, param : String) -> UInt16
    {
        /// ASL A is a thing
        if param == "A"
        {
            AddInstruction(offset + 0x0A); return 1
        }
        
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .ZeroPage :  AddInstruction(offset + 0x06); AddByte(lsb); return 2
        case .ZeroPageX : AddInstruction(offset + 0x16); AddByte(lsb); return 2
            
        case .Absolute :  AddInstruction(offset + 0x0E); AddByte(lsb); AddByte(msb); return 3
        case .AbsoluteX : AddInstruction(offset + 0x1E); AddByte(lsb); AddByte(msb); return 3
            
        case .Error : perror(error: param);return 0
            
        default : perror(error: param);return 0
        }
    }
    
    
    private func BIT(param : String) -> UInt16
    {
        
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .ZeroPage :  AddInstruction(0x24); AddByte(lsb); return 2
        case .Absolute :  AddInstruction(0x2c); AddByte(lsb); AddByte(msb); return 3
        case .Immediate : AddInstruction(0x89); AddByte(lsb); return 2
        case .ZeroPageX : AddInstruction(0x34); AddByte(lsb); return 2
        case .AbsoluteX : AddInstruction(0x3c); AddByte(lsb); AddByte(msb); return 3
            
        case .Error : perror(error: param);return 0
            
        default : perror(error: param);return 0
        }
    }
    
    private func TESTBITS(offset : UInt8, param : String) -> UInt16
    {
        
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .ZeroPage :  AddInstruction(0x04); AddByte(lsb); return 2
        case .Absolute :  AddInstruction(0x0c); AddByte(lsb); AddByte(msb); return 3
            
            
        case .Error : perror(error: param);return 0
            
        default : perror(error: param);return 0
        }
    }
    
    
    private func CPXCPY(offset : UInt8, param : String) -> UInt16
    {
        
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .ZeroPage :  AddInstruction(offset + 0x04); AddByte(lsb); return 2
        case .Absolute :  AddInstruction(offset + 0x0c); AddByte(lsb); AddByte(msb); return 3
        case .Immediate : AddInstruction(offset); AddByte(lsb); return 2
            
        case .Error : perror(error: param);return 0
            
        default : perror(error: param);return 0
        }
    }
    
    private func INCDEC(offset : UInt8, param : String) -> UInt16
    {
        /// INC A is a thing
        if param == "A" && offset == 0xc0
        {
            AddInstruction(offset + 0x3A); return 1
        }
        if param == "A" && offset == 0xE0
        {
            AddInstruction(offset + 0x1A); return 1
        }
        
        let r = GetAddresingMode(token: param)
        let lsb = UInt8( r.address & 0x00FF)
        let msb = UInt8( r.address >> 8)
        
        switch r.mode {
        case .ZeroPage :  AddInstruction(offset + 0x06); AddByte(lsb); return 2
        case .ZeroPageX :  AddInstruction(offset + 0x16); AddByte(lsb); return 2
        case .Absolute :  AddInstruction(offset + 0x0e); AddByte(lsb); AddByte(msb); return 3
        case .AbsoluteX : AddInstruction(offset + 0x1e); AddByte(lsb); return 2
            
        case .Error : perror(error: param);return 0
            
        default : perror(error: param);return 0
        }
    }
    
    
    
    /// Used by multiple instructions to devine the addressing mode from the syntax of the params
    /// after the instruction
    
    private func GetAddresingMode(token : String) -> (address : UInt16, mode : AddressingModes)
    {
        
        if token.starts(with: "#")
        {
            let n = GetNumber(input: token.replacingOccurrences(of: "#", with: ""))
            
            if n != nil
            {
                return (UInt16(n!), .Immediate)
            }
            else
            {
                perror(error: token)
                return (0, .Error)
                
            }
        }
        
        
        /// (indirect) e.g. ADC ($12)
        if token.contains("(") && !token.contains("X") && !token.contains("Y")
        {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "X", with: "")
            newToken = newToken.replacingOccurrences(of: "Y", with: "")
            let n = GetAddress(input: newToken)
            if n != nil
            {
                return (UInt16(n!), .Indirect)
            }
            else
            {
                perror(error: token)
            }
        }
        
        
        /// (indirect,X) e.g. ADC ($12,X)
        if token.contains("(") && token.contains("X")
        {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "X", with: "")
            newToken = newToken.replacingOccurrences(of: ",", with: "")
            
            let n = GetAddress(input: newToken)
            if n != nil
            {
                return (UInt16(n!), .IndirectX)
            }
            else
            {
                perror(error: token)
            }
        }
        
        /// (indirect),Y e.g. ADC ($12),Y
        if token.contains("(") && token.contains("Y")
        {
            var newToken = token.replacingOccurrences(of: "(", with: "")
            newToken = newToken.replacingOccurrences(of: ")", with: "")
            newToken = newToken.replacingOccurrences(of: "Y", with: "")
            newToken = newToken.replacingOccurrences(of: ",", with: "")
            
            let n = GetAddress(input: newToken)
            if n != nil
            {
                return (UInt16(n!), .IndirectY)
            }
            else
            {
                perror(error: token)
            }
        }
        
        
        
        
        if token.contains(",Y")
        {
            let n = GetAddress(input: token.replacingOccurrences(of: ",Y", with: ""))
            
            if n != nil
            {
                return (UInt16(n!), .AbsoluteY)
            }
            else
            {
                perror(error: token)
            }
        }
        
        if !token.contains(",X")
        {
            let n = GetAddress(input: token)
            
            if n != nil
            {
                if UInt16(n!) < 256
                {
                    return (UInt16(n!), .ZeroPage)
                }
                else
                {
                    return (UInt16(n!), .Absolute)
                }
            }
            else
            {
                perror(error: token)
            }
        }
        
        if token.contains(",X")
        {
            
            let n = GetAddress(input: token.replacingOccurrences(of: ",X", with: ""))
            
            if n != nil
            {
                if UInt16(n!) < 256
                {
                    return (UInt16(n!), .ZeroPageX)
                }
                else
                {
                    return (UInt16(n!), .AbsoluteX)
                }
            }
            else
            {
                perror(error: token)
            }
        }
        
        
        
        return (0, .Error)
    }
    
    
    func ORG(address : String) -> UInt16
    {
        
        let num = GetAddress(input: address)
        
        if num == nil{
            perror(error: "Unable to parse address value: " + address)
            return 0
        }
        else
        {
            return num!
        }
        
        
    }
    
    func EQU(address : String) -> UInt16
    {
        
        let num = GetAddress(input: address)
        
        if num == nil{
            perror(error: "Unable to assign value to label " + address)
            return 0
        }
        else
        {
            return num!
        }
        
        
    }
    
    func DB(data : String) -> UInt16
    {
        
        var counter : UInt16 = 0
        
        if data.contains("\"")
        {
            /// Deal with it as a string
            
            let newdata = data.replacingOccurrences(of: "\"", with: "")
            
            for eachChar in newdata
            {
                let c =  (eachChar as Character).asciiValue!
                AddByte(c);
                counter = counter + 1
            }
            
            return counter
        }
        
        let bytes = data.components(separatedBy: ",")
        
        for byte in bytes
        {
            let num = GetNumber(input: byte)
            if num == nil{
                perror(error: "Number parse error or extra spaces between values: " + data)
                return 0
            }
            else
            {
                AddByte(num!);
            }
            
            counter = counter + 1
        }
        
        return counter
        
        
        
    }
    
    
    
}


/// Extensions

extension String {
    
    /// Returns a condensed string, with no extra whitespaces and no new lines.
    var condensed: String {
        return replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
    }
    
    /// Returns a condensed string, with no whitespaces at all and no new lines.
    var extraCondensed: String {
        return replacingOccurrences(of: "[\\s\n]+", with: "", options: .regularExpression, range: nil)
    }
    
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


