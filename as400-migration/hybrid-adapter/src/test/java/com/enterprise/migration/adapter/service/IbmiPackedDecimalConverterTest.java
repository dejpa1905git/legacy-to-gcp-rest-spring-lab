package com.enterprise.migration.adapter.service;

import com.ibm.as400.access.AS400PackedDecimal;
import com.ibm.as400.access.AS400Text;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class IbmiPackedDecimalConverterTest {

    @Test
    @DisplayName("Verify AS400PackedDecimal conversions for INVCALC/GETINV01 parameter formats")
    void testPackedDecimalConversion() {
        // outCustNo: packed(6:0) -> 4 bytes
        AS400PackedDecimal packedCustNo = new AS400PackedDecimal(6, 0);
        assertEquals(4, packedCustNo.getByteLength());
        byte[] custBytes = packedCustNo.toBytes(new BigDecimal("100001"));
        BigDecimal decodedCust = (BigDecimal) packedCustNo.toObject(custBytes);
        assertEquals(new BigDecimal("100001"), decodedCust);

        // outInvAmt: packed(11:2) -> 6 bytes
        AS400PackedDecimal packedInvAmt = new AS400PackedDecimal(11, 2);
        assertEquals(6, packedInvAmt.getByteLength());
        byte[] amtBytes = packedInvAmt.toBytes(new BigDecimal("3920.75"));
        BigDecimal decodedAmt = (BigDecimal) packedInvAmt.toObject(amtBytes);
        assertEquals(new BigDecimal("3920.75"), decodedAmt);

        // outDueDate: packed(8:0) -> 5 bytes
        AS400PackedDecimal packedDueDate = new AS400PackedDecimal(8, 0);
        assertEquals(5, packedDueDate.getByteLength());
        byte[] dueBytes = packedDueDate.toBytes(new BigDecimal("20261001"));
        BigDecimal decodedDueDate = (BigDecimal) packedDueDate.toObject(dueBytes);
        assertEquals(new BigDecimal("20261001"), decodedDueDate);

        // text conversion for char(10)
        AS400Text text10 = new AS400Text(10);
        assertEquals(10, text10.getByteLength());
        byte[] textBytes = text10.toBytes("INV-1001");
        String decodedText = (String) text10.toObject(textBytes);
        assertNotNull(decodedText);
        assertEquals("INV-1001", decodedText.trim());
    }
}

