import { boot } from 'quasar/wrappers'
import axios from 'axios'

// Be careful when using SSR for cross-request state pollution
// due to creating a Singleton instance here;
// If any client changes this (global) instance, it might be a
// good idea to move this instance creation inside of the
// "export default () => {}" function below (which runs individually
// for each client)
const apiHosting = axios.create({ baseURL: '/hosting' })
const apiUser = axios.create({ baseURL: '/user' })

export default boot(({ app }) => {
  // for use inside Vue files (Options API) through this.$axios and this.$api

  app.config.globalProperties.$axios = axios
  // ^ ^ ^ this will allow you to use this.$axios (for Vue Options API form)
  //       so you won't necessarily have to import axios in each vue file

  app.config.globalProperties.$apiHosting = apiHosting
  // ^ ^ ^ this will allow you to use this.$apiHosting (for Vue Options API form)
  //       so you can easily perform requests against your app's API

  app.config.globalProperties.$apiUser = apiUser
  // ^ ^ ^ this will allow you to use this.$apiUser (for Vue Options API form)
  //       so you can easily perform requests against your app's API
})

export { apiHosting, apiUser }
