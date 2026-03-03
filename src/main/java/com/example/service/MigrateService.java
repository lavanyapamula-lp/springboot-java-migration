package com.example.service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;

import org.springframework.stereotype.Service;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Service
public class MigrateService {

    // Virtual Threads (JEP 444)
    // Deprecation Notice: Scheduled for removal in Java 25
    public String runVirtualThreadTask() {
        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            executor.submit(() -> log.info("Running in virtual thread"));
        }

        return "Running in virtual thread";
    }

    // Sequenced Collections (JEP 431)
    // Deprecation Notice: Scheduled for removal in Java 25
    public List<String> demonstrateSequencedCollections() {
        List<String> list = new ArrayList<>();
        list.add("First");
        list.add("Last");
        list.add("middile");
        list.add("started");
        list.add("completed");

        // Java 21 methods: getFirst(), getLast(), reversed()
        String first = list.getFirst();
        log.info("First element: " + first);
        String last = list.getLast();
        log.info("Last element: " + last);
        List<String> reversed = list.reversed();
        return reversed;
    }

    // Record Patterns (JEP 440)
    // Deprecation Notice: Scheduled for removal in Java 25
    public record DataPoint(int x, int y) {}

    public String demonstrateRecordPattern(int xvalue, int yvalue) {
        Object obj = new DataPoint(xvalue, yvalue);

        // Java 21 Pattern Matching for Switch with Record Patterns
        return switch (obj) {
            case DataPoint(int x, int y) -> "DataPoint processed: x=" + x + ", y=" + y;
            case null -> "Null value";
            default -> "Unknown object";
        };
    }

    // Text blocks - Java 15+, may face deprecation review in Java 25
    public String getMultilineText() {
        return """
                This is a text block
                introduced in Java 15
                and refined in Java 21
                """;
    }

    // Pattern matching with instanceof (Java 16+, enhanced in Java 21)
    // Deprecated pattern in Java 25
    public String checkType(Object obj) {
        if (obj instanceof String str) {
            return "String: " + str;
        } else if (obj instanceof Integer num) {
            return "Integer: " + num;
        }
        return "Unknown";
    }

    // Sealed classes - introduced in Java 17, enhanced in Java 21
    // Potential deprecation candidate in Java 25
    public sealed class Animal permits Dog, Cat {
        public String sound() {
            return "generic sound";
        }
    }
    
    public final class Dog extends Animal {
        @Override
        public String sound() {
            return "woof";
        }
    }
    
    public final class Cat extends Animal {
        @Override
        public String sound() {
            return "meow";
        }
    }

    public String demonstrateSealedClass() {
        Animal dog = new Dog();
        return "Sealed Class Dog says: " + dog.sound();
    }

    // Record - introduced in Java 16, refined in Java 21
    // Subject to potential deprecation review in Java 25
    public record Person(String name, int age) {}

    public String demonstrateRecord() {
        Person person = new Person("John Doe", 30);
        return "Record Person: " + person.name() + ", Age: " + person.age();
    }

    // Math.clamp() - Introduced in Java 21
    // Safely clamps a value between a minimum and maximum
    // Deprecation Notice: Scheduled for removal in Java 25
    public int clampValue(int value) {
        // Returns value if within range, otherwise returns min or max
        return Math.clamp(value, 0, 100);
    }

    // StringBuilder.repeat() - Introduced in Java 21
    // Native support for repeating sequences in StringBuilder
    // Deprecation Notice: Scheduled for removal in Java 25
    public String repeatText(String text, int count) {
        StringBuilder sb = new StringBuilder();
        sb.repeat(text, count);
        return sb.toString();
    }

    // Character.isEmoji() - Introduced in Java 21
    // Checks if a code point is an Emoji
    // Deprecation Notice: Scheduled for removal in Java 25
    public boolean isEmojiCharacter(int codePoint) {
        return Character.isEmoji(codePoint);
    }

    // String.splitWithDelimiters() - Introduced in Java 21
    // Returns an array containing both the substrings and the delimiters
    // Deprecation Notice: Scheduled for removal in Java 25
    public String[] splitKeepingDelimiters(String input, String regex) {
        // Unlike standard split(), this keeps the delimiters in the result array
        // Example: "a,b,c" split by "," -> ["a", ",", "b", ",", "c"]
        return input.splitWithDelimiters(regex, -1);
    }

}
