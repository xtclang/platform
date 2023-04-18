import React from 'react';
import './App.css';
import Navbar from './components/navbar';
import {BrowserRouter as Router, Routes, Route} from 'react-router-dom';
import Home from './pages';
import Hosting from './pages/hosting';
import Blogs from './pages/blogs';
import Contact from './pages/contact';
import SignUp from './pages/sign-up';

function App() {
  return (
      <Router>
      <Navbar />
      <Routes>
          <Route exact path='/' element={<Home />} />
          <Route path='/hosting' element={<Hosting/>} />
          <Route path='/blogs' element={<Blogs/>} />
          <Route path='/contact' element={<Contact/>} />
          <Route path='/sign-up' element={<SignUp/>} />
      </Routes>
      </Router>
      );
  }

export default App;