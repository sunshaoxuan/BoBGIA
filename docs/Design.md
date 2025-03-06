# 跨平台地图路线规划助手设计文档

## 1. 技术栈选择

- **开发框架**：  
  - **Flutter**
    - **理由**：
      - 支持 iOS、Android 以及桌面平台（Windows、macOS）。
      - 丰富的现成组件和插件（例如 google_maps_flutter）。
      - 单一代码库开发，便于统一维护与发布。

- **编程语言**：  
  - **Dart**：Flutter 默认使用的语言，语法现代且高效。

- **地图服务**：  
  - **Google Maps API**
    - 用于地图显示、标记与路线规划。
    - 除了经纬度信息外，Google地址对于已注册的地址支持地图码功能，能更加精确地定位地址。
    - 可选择 google_maps_flutter 插件实现 Flutter 集成。

- **地址解析与标准化**：  
  - **AI OpenAPI**（例如 Gemini）
    - 通过调用 AI 接口对用户输入的地址进行语言解析、标准化及整理。
    - 在解析过程中，同时提取地图码信息（如果存在），以便精确定位。

- **路线规划**：
  - 使用 Google Maps Directions API 进行最优驾驶路线规划。
  - 若需要进行更复杂的动态路线调整，可引入第三方路线规划库并结合 AI API 的辅助。

- **其他辅助接口**：  
  - 根据业务需求，可以集成 Grok 或 OpenAI 接口，用于处理动态数据或复杂流程逻辑。

## 2. 架构设计

### 2.1 总体架构

\[
\text{UI 层} \longleftrightarrow \text{业务逻辑层} \longleftrightarrow \text{数据访问与接口调用层}
\]

- **UI 层**：
  - 负责地图显示、地址输入、地址列表选择、途经点点击及视图反馈。
  - 使用 Flutter 的 Widget 系统构建响应式界面。

- **业务逻辑层**：
  - 处理地址解析、标准化、路由规划与动态调整。
  - 提供状态管理（如使用 Provider 或 Bloc）以便管理地图标记、路线列表等数据状态。

- **数据访问与接口调用层**：
  - 封装 Google Maps API、Directions API 的调用。
  - 封装 AI OpenAPI 调用接口（Gemini、Grok、OpenAI）。
  - 采用数据传输对象（DTO）与业务对象（BO）进行数据流管理。

### 2.2 数据传输对象与业务逻辑设计

- **数据传输对象（DTO）设计**：
  - **AddressDTO**：
    - 属性：  
      - 原始地址  
      - 标准化地址  
      - 经纬度  
      - 地图码（若存在，用于精确定位）  
      - 解析状态等。
  - **RouteDTO**：
    - 属性：途经点列表、总路程、总耗时、各段详细路线、费用等。
  - **UserLocationDTO**：
    - 属性：设备当前所在位置（经纬度）、精度信息等。

- **业务逻辑类设计**：
  - **AddressManager**
    - 方法：
      - \(\texttt{normalizeAddress(String rawAddress): Future<AddressDTO>}\)
      - 调用 Gemini API 对地址进行解析与标准化，同时提取地图码信息。
  - **MapManager**
    - 方法：
      - \(\texttt{markSingleAddress(AddressDTO address)}\)
      - \(\texttt{markMultipleAddresses(List<AddressDTO> addresses)}\)
      - 实现地址标记与视觉反馈。对于具有地图码的地址，可优先使用地图码进行精确标记。
  - **RoutePlanner**
    - 方法：
      - \(\texttt{planOptimalRoute(UserLocationDTO currentLocation, List<AddressDTO> destinations): Future<RouteDTO>}\)
      - \(\texttt{adjustRoute(List<AddressDTO> waypoints): Future<RouteDTO>}\)
      - 根据用户输入的调整重新计算路线，调用 Google Maps Directions API 及/或辅助 AI 接口，确保在规划过程中考虑地图码带来的定位优势。
  - **UIController (或 ViewModel)**
    - 负责收集用户输入、协调 AddressManager、MapManager 与 RoutePlanner 之间的逻辑交互。
    - 响应 UI 事件（例如地址输入、标记点击、路线调整），并更新 UI 状态。

## 3. 模块间交互

1. 用户输入或选择地址后，调用 \(\texttt{AddressManager.normalizeAddress()}\) 进行地址解析与标准化，同时获取地图码（如果可以获取）。
2. 将标准化后的地址和地图码信息传递给 \(\texttt{MapManager}\)，在 Google 地图上进行标记，优先使用地图码以确保准确定位。
3. 用户选择多个地址后，调用 \(\texttt{RoutePlanner.planOptimalRoute()}\) 计算最优路线。
4. 用户点击地图中途点调整顺序，触发 \(\texttt{RoutePlanner.adjustRoute()}\)，返回新的路线规划结果。
5. 后台通信部分根据请求调用相应的 API（Google Maps、Gemini、Grok、OpenAI），并返回结果供业务逻辑层处理。

## 4. 异常处理与优化

- **异常处理**：
  - 针对地址解析失败、地图加载异常、API 请求超时等情况设计统一的错误捕获及用户提示机制。
  - 设计重试机制及在必要时使用离线数据缓存。

- **性能优化**：
  - 合理缓存已解析地址、地图码及路线数据。
  - 对频繁操作（如地图交互与途经点调整）采用节流或防抖动处理。
  - 后台异步加载数据，确保 UI 响应流畅。 