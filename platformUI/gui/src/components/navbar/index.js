import React from "react";
import {Nav, NavLink, NavMenu} from "./NavbarElements";

const Navbar = () =>
  {
  return (
    <>
    <Nav>
      <NavMenu>
      <NavLink to="/" activestyle="true">
        Home
      </NavLink>
      <NavLink to="/hosting" activestyle="true">
        Hosting
      </NavLink>
      <NavLink to="/blogs" activestyle="true">
        Blogs
      </NavLink>
      <NavLink to="/contact" activestyle="true">
        Contact Us
      </NavLink>
      <NavLink to="/sign-up" activestyle="true">
        Sign Up
      </NavLink>
      </NavMenu>
    </Nav>
    </>
    );
  };

export default Navbar;