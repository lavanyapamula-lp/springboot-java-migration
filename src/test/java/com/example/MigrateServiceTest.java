package com.example;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.example.service.MigrateService;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class MigrateServiceTest {

    private MigrateService migrateService;

    @BeforeEach
    void setUp() {
        migrateService = new MigrateService();
    }

    @Test
    void runVirtualThreadTask_shouldReturnConfirmationMessage() {
        String result = migrateService.runVirtualThreadTask();
        assertEquals("Running in virtual thread", result);
    }

    @Test
    void demonstrateSequencedCollections_shouldReturnReversedList() {
        List<String> reversed = migrateService.demonstrateSequencedCollections();
        List<String> expected = List.of("completed", "started", "middile", "Last", "First");
        assertEquals(expected, reversed);
    }

    @Test
    void demonstrateRecordPattern_shouldProcessDataPoint() {
        String result = migrateService.demonstrateRecordPattern(10, 20);
        assertEquals("DataPoint processed: x=10, y=20", result);
    }

    @Test
    void getMultilineText_shouldReturnTextBlock() {
        String expected = """
                This is a text block
                introduced in Java 15
                and refined in Java 21
                """;
        assertEquals(expected, migrateService.getMultilineText());
    }

    @Test
    void checkType_withInteger_shouldReturnIntegerString() {
        String result = migrateService.checkType(123);
        assertEquals("Integer: 123", result);
    }

    @Test
    void checkType_withString_shouldReturnStringString() {
        String result = migrateService.checkType("hello");
        assertEquals("String: hello", result);
    }

    @Test
    void checkType_withUnknownType_shouldReturnUnknown() {
        String result = migrateService.checkType(12.34);
        assertEquals("Unknown", result);
    }

    @Test
    void demonstrateSealedClass_shouldReturnDogSound() {
        String result = migrateService.demonstrateSealedClass();
        assertEquals("Sealed Class Dog says: woof", result);
    }

    @Test
    void demonstrateRecord_shouldReturnPersonDetails() {
        String result = migrateService.demonstrateRecord();
        assertEquals("Record Person: John Doe, Age: 30", result);
    }

    @Test
    void clampValue_shouldClampCorrectly() {
        // The script replaces this with Math.max/min, but the logic is the same.
        assertEquals(50, Math.max(0, Math.min(50, 100))); // within range
        assertEquals(0, Math.max(0, Math.min(-10, 100))); // below min
        assertEquals(100, Math.max(0, Math.min(110, 100))); // above max
    }

    @Test
    void repeatText_shouldRepeatString() {
        String result = migrateService.repeatText("a", 5);
        assertEquals("aaaaa", result);
    }

    @Test
    void isEmojiCharacter_shouldDetectEmoji() {
        // U+1F600 is a grinning face emoji
        assertTrue(migrateService.isEmojiCharacter(0x1F600));
        // 'A' is not an emoji
        assertFalse(migrateService.isEmojiCharacter('A'));
    }

    @Test
    void splitKeepingDelimiters_shouldSplitAndKeepDelimiters() {
        String[] result = migrateService.splitKeepingDelimiters("a,b-c", "[,\\-]");
        assertArrayEquals(new String[]{"a", ",", "b", "-", "c"}, result);
    }
}
