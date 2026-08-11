import axios from 'axios';

const { apiHost = '' } = window.starchatsConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
