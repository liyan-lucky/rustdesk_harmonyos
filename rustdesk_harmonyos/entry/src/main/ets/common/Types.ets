/**
 * 通用类型定义
 */

// 控制请求参数类型 - 使用Record替代索引签名
export type ControlParams = Record<string, string | number | boolean | ControlParams[]>;

// 控制响应数据类型 - 使用Record替代索引签名
export type ControlResponseData = Record<string, string | number | boolean | ControlResponseData[]>;

// TextEncoder和TextDecoder在HarmonyOS中是内置的，不需要声明
// 直接使用内置类型