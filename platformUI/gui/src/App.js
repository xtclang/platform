import React from 'react';
import './App.css';
import Navbar from './components/navbar';
import {BrowserRouter as Router, Routes, Route} from 'react-router-dom';
import Home from './pages';
import About from './pages/about';
import Blogs from './pages/blogs';
import SignIn from './pages/sign-in';
import Contact from './pages/contact';

function App() {
  return (
      <Router>
      <Navbar />
      <Routes>
          <Route exact path='/' element={<Home />} />
          <Route path='/about' element={<About/>} />
          <Route path='/contact' element={<Contact/>} />
          <Route path='/blogs' element={<Blogs/>} />
          <Route path='/sign-in' element={<SignIn/>} />
      </Routes>
      </Router>
      );
  }

export default App;