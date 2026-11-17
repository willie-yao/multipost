package org.example.crossposting

import org.junit.Assert.*
import org.junit.Test
import java.util.Base64

class XTextParserTest {
    @Test fun rejectsForbiddenCharactersAndEmptyText() {
        assertEquals(false, XTextParser.measure("\uFFFF")["valid"])
        assertEquals(false, XTextParser.measure("")["valid"])
        assertEquals(1, XTextParser.measure("e\u0301")["units"])
    }
    @Test fun officialV3Conformance() {
        val lines = javaClass.getResourceAsStream("/weighted-v3.tsv")!!.bufferedReader().readLines()
        assertEquals(22, lines.size)
        for ((index, line) in lines.withIndex()) {
            val fields = line.split('\t')
            val text = String(Base64.getDecoder().decode(fields[0]), Charsets.UTF_8)
            val result = XTextParser.measure(text)
            assertEquals("weighted fixture $index", fields[1].toInt(), result["units"])
            assertEquals("validity fixture $index", fields[2].toBoolean(), result["valid"])
        }
    }
}
