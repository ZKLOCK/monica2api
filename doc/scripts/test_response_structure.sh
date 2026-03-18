#!/bin/bash

# 测试响应结构问题
echo "=== 测试响应结构问题 ==="

# 模拟可能的问题场景
cat > test_cases.go << 'EOF'
package main

import (
	"fmt"
	"github.com/sashabaranov/go-openai"
)

func testCase1() {
	// 场景1: Choices 为空
	response := &openai.ChatCompletionResponse{
		ID:      "test-id",
		Object:  "chat.completion",
		Created: 1234567890,
		Model:   "claude-4-sonnet",
		Choices: []openai.ChatCompletionChoice{}, // 空数组
	}
	
	fmt.Println("场景1 - Choices 为空:")
	fmt.Printf("  Choices长度: %d\n", len(response.Choices))
	// 下面这行会panic
	// fmt.Printf("  Content长度: %d\n", len(response.Choices[0].Message.Content))
}

func testCase2() {
	// 场景2: Message 可能为nil
	var choices []openai.ChatCompletionChoice
	// 不初始化Choices[0].Message
	
	response := &openai.ChatCompletionResponse{
		ID:      "test-id",
		Object:  "chat.completion",
		Created: 1234567890,
		Model:   "claude-4-sonnet",
		Choices: choices,
	}
	
	fmt.Println("\n场景2 - 未初始化的Choices:")
	fmt.Printf("  Choices长度: %d\n", len(response.Choices))
}

func testCase3() {
	// 场景3: 正常的响应
	response := &openai.ChatCompletionResponse{
		ID:      "test-id",
		Object:  "chat.completion",
		Created: 1234567890,
		Model:   "claude-4-sonnet",
		Choices: []openai.ChatCompletionChoice{
			{
				Index: 0,
				Message: openai.ChatCompletionMessage{
					Role:    "assistant",
					Content: "Hello",
				},
				FinishReason: "stop",
			},
		},
	}
	
	fmt.Println("\n场景3 - 正常的响应:")
	fmt.Printf("  Choices长度: %d\n", len(response.Choices))
	fmt.Printf("  Content: %s\n", response.Choices[0].Message.Content)
	fmt.Printf("  Content长度: %d\n", len(response.Choices[0].Message.Content))
}

func main() {
	testCase1()
	testCase2()
	testCase3()
}
EOF

echo "编译并运行测试..."
go run test_cases.go

# 清理
rm -f test_cases.go

echo -e "\n=== 测试完成 ==="
echo -e "\n建议:"
echo "1. 在访问 response.Choices[0] 前检查长度"
echo "2. 确保 Message 字段被正确初始化"
echo "3. 添加防御性编程"