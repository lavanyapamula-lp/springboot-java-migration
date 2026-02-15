package com.example;

import com.example.controller.MigrateController;
import com.example.entities.Student;
import com.example.repositories.StudentRepository;
import com.example.service.MigrateService;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Arrays;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(MigrateController.class)
@ExtendWith(MockitoExtension.class)
class MigrateControllerTest {

    @TestConfiguration
    static class TestConfig {
        @Bean
        public MigrateService migrateService() {
            return mock(MigrateService.class);
        }
        
        @Bean
        public StudentRepository studentRepository() {
            return mock(StudentRepository.class);
        }
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private MigrateService migrateService;

    @Autowired
    private StudentRepository studentRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void hello_shouldReturnDefaultMessage() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(content().string("Hello World!"));
    }

    @Test
    void getVirtualThread_shouldReturnServiceResponse() throws Exception {
        when(migrateService.runVirtualThreadTask()).thenReturn("Mocked virtual thread response");

        mockMvc.perform(get("/virtualThread"))
                .andExpect(status().isOk())
                .andExpect(content().string("Mocked virtual thread response"));
    }

    @Test
    void getSequencedCollections_shouldReturnReversedList() throws Exception {
        List<String> reversedList = Arrays.asList("completed", "started", "middile", "Last", "First");
        when(migrateService.demonstrateSequencedCollections()).thenReturn(reversedList);

        mockMvc.perform(get("/sequencedCollections"))
                .andExpect(status().isOk())
                .andExpect(content().json(objectMapper.writeValueAsString(reversedList)));
    }

    @Test
    void getRecordPattern_shouldReturnProcessedString() throws Exception {
        when(migrateService.demonstrateRecordPattern(10, 20)).thenReturn("DataPoint processed: x=10, y=20");

        mockMvc.perform(get("/recordPattern")
                        .param("x", "10")
                        .param("y", "20"))
                .andExpect(status().isOk())
                .andExpect(content().string("DataPoint processed: x=10, y=20"));
    }

    @Test
    void getMultiline_shouldReturnTextBlock() throws Exception {
        String textBlock = """
                This is a text block
                introduced in Java 15
                and refined in Java 21
                """;
        when(migrateService.getMultilineText()).thenReturn(textBlock);

        mockMvc.perform(get("/multiline"))
                .andExpect(status().isOk())
                .andExpect(content().string(textBlock));
    }

    @Test
    void checkType_withInteger_shouldReturnIntegerType() throws Exception {
        when(migrateService.checkType(any(Integer.class))).thenReturn("Integer: 123");

        mockMvc.perform(get("/checkType").param("input", "123"))
                .andExpect(status().isOk())
                .andExpect(content().string("Integer: 123"));
    }

    @Test
    void checkType_withString_shouldReturnStringType() throws Exception {
        when(migrateService.checkType(any(String.class))).thenReturn("String: abc");

        mockMvc.perform(get("/checkType").param("input", "abc"))
                .andExpect(status().isOk())
                .andExpect(content().string("String: abc"));
    }

    @Test
    void addStudent_shouldReturnSavedStudent() throws Exception {
        Student savedStudent = new Student();
        savedStudent.setId(100l);
        savedStudent.setName("TestName");
        when(studentRepository.save(any(Student.class))).thenReturn(savedStudent);
        
        mockMvc.perform(get("/addStudent").param("name", "TestName"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(100))
                .andExpect(jsonPath("$.name").value("TestName"));
    }
}