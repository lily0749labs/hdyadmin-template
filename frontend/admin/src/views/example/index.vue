<script setup lang="ts">
import { ref } from 'vue';

import { Page } from 'shell/vben/common-ui';

import { exampleService } from '../../api/client';

const name = ref('Codex');
const message = ref('');
const error = ref('');
const loading = ref(false);

async function checkConnection() {
  loading.value = true;
  message.value = '';
  error.value = '';
  try {
    const response = await exampleService.SayHello({ name: name.value });
    message.value = response.message ?? '';
  } catch (reason) {
    error.value = reason instanceof Error ? reason.message : String(reason);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <Page title="hdyadmin 模块连通性检查">
    <section class="example-card">
      <p>调用示例接口，验证宿主前端、Core 动态代理和模块 gRPC 服务。</p>
      <div class="example-form">
        <input v-model="name" aria-label="Name" placeholder="请输入名称" />
        <button type="button" :disabled="loading || !name" @click="checkConnection">
          {{ loading ? '请求中…' : '调用接口' }}
        </button>
      </div>
      <p v-if="message" class="success">{{ message }}</p>
      <p v-if="error" class="error">{{ error }}</p>
    </section>
  </Page>
</template>

<style scoped>
.example-card {
  max-width: 720px;
  padding: 24px;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  background: #fff;
}

.example-form {
  display: flex;
  gap: 12px;
  margin-top: 20px;
}

input {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
}

button {
  padding: 8px 16px;
  border: 0;
  border-radius: 6px;
  color: #fff;
  background: #2563eb;
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.success {
  color: #15803d;
}

.error {
  color: #b91c1c;
}
</style>
