import axios from 'axios'

const apiModule = axios.create({ baseURL: '/module' })
const apiUser   = axios.create({ baseURL: '/user' })
const apiWebApp = axios.create({ baseURL: '/apps' })

export { apiModule, apiUser, apiWebApp }