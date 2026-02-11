package com.example.controller;

import java.util.List;

import lombok.Data;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.entities.Student;
import com.example.repositories.StudentRepository;
import com.example.service.MigrateService;

import org.springframework.web.bind.annotation.GetMapping;


@RestController
public class MigrateController {
    // @Autowired
    // NamedParameterJdbcTemplate jdbcTemplate;

    @Autowired
    MigrateService migrateService;

    @Autowired
    StudentRepository studentRepository;


    @RequestMapping("/")
    String hello() {
        return "Hello World!";
    }

    @Data
    static class Result {
        private final int left;
        private final int right;
        private final long answer;
    }

    // SQL sample
    // @RequestMapping("calc")
    // Result calc(@RequestParam int left, @RequestParam int right) {
    //     MapSqlParameterSource source = new MapSqlParameterSource()
    //             .addValue("left", left)
    //             .addValue("right", right);
    //     return jdbcTemplate.queryForObject("SELECT :left + :right AS answer", source,
    //             (rs, rowNum) -> new Result(left, right, rs.getLong("answer")));
    // }

    @GetMapping("virtualThread")
    public String getVirtualThread() {
        return migrateService.runVirtualThreadTask();
    }

    @GetMapping("sequencedCollections")
    public List<String> getSequencedCollections() {
        return migrateService.demonstrateSequencedCollections();
    }

    @GetMapping("recordPattern")
    public String getRecordPattern(@Valid @RequestParam int x, @RequestParam int y) {
        return migrateService.demonstrateRecordPattern(x, y);
    }

    @GetMapping("multiline")
    public String getMultiline() {
        return migrateService.getMultilineText();
    }

    @GetMapping("checkType")
    public String checkType(@RequestParam String input) {
        try {
            return migrateService.checkType(Integer.parseInt(input));
        } catch (NumberFormatException e) {
            return migrateService.checkType(input);
        }
    }

    @GetMapping("sealedClass")
    public String getSealedClass() {
        return migrateService.demonstrateSealedClass();
    }

    @GetMapping("personRecord")
    public String getPersonRecord() {
        return migrateService.demonstrateRecord();
    }

    @GetMapping("clamp")
    public int getClampValue(@RequestParam int value) {
        return migrateService.clampValue(value);
    }

    @GetMapping("repeat")
    public String getRepeatText(@RequestParam String text, @RequestParam int count) {
        return migrateService.repeatText(text, count);
    }

    @GetMapping("emoji")
    public boolean isEmoji(@RequestParam int codePoint) {
        return migrateService.isEmojiCharacter(codePoint);
    }

    @GetMapping("split")
    public String[] getSplitWithDelimiters(@RequestParam String input, @RequestParam String regex) {
        return migrateService.splitKeepingDelimiters(input, regex);
    }

    @GetMapping("addStudent")
    public Student addStudent(@RequestParam String name) {
        return studentRepository.save(new Student(null, name));
    }

    @GetMapping("legacyThreads")
    public String getLegacyThreads() {
        migrateService.demonstrateLegacyThreadMethods();
        return "Legacy thread methods executed";
    }

    @GetMapping("runFinalization")
    public String getRunFinalization() {
        migrateService.demonstrateFinalization();
        return "Runtime.runFinalization() executed";
    }

    @GetMapping("finalize")
    public String callFinalize() throws Throwable {
        migrateService.finalize();
        return "finalize() called manually";
    }
}
